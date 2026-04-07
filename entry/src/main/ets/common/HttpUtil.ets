import { http } from '@kit.NetworkKit';
import preferencesUtil from './PreferencesUtil';
import { Schedule, ScheduleContent, ScheduleListResponse, ScheduleDetailResponse,
  ScheduleCreateResponse, ScheduleSimpleResponse, QuantityResponse } from './ScheduleModel';

const BASE_URL = 'http://192.168.43.231:5000';
const DEEPSEEK_API_URL = 'https://api.deepseek.com/chat/completions';
const DEEPSEEK_API_KEY = 'sk-75c8d51cfa0d404dac8fd5414bd3bf31';

interface AuthRequest {
  username: string;
  password: string | number;
}

interface AuthResponse {
  success: boolean;
  error?: string;
  user_id?: string;
}

interface DeepSeekMessage {
  role: string;
  content: string;
}

interface DeepSeekChoice {
  message: DeepSeekMessage;
}

interface DeepSeekResponse {
  choices: DeepSeekChoice[];
}

interface ScheduleCreateRequest {
  schedules: Schedule[];
}

interface ScheduleUpdateRequest {
  schedule: Schedule;
}

interface DeepSeekRequestBody {
  model: string;
  messages: DeepSeekMessage[];
  temperature: number;
}

class HttpUtil {
  private cookie: string = '';
  private userId: string = '';

  async loadCookie(): Promise<void> {
    this.cookie = await preferencesUtil.getCookie();
    this.userId = await preferencesUtil.getUserId();
  }

  setCookie(cookie: string): void {
    this.cookie = cookie;
  }

  getCookie(): string {
    return this.cookie;
  }

  setUserId(id: string): void {
    this.userId = id;
  }

  private cleanTimeArr(arr: string[]): string[] {
    // Ensure time array is ["YYYY-MM-DD", "HH:MM:SS"] with no extra spaces
    if (arr.length < 2) return arr;
    const datePart: string = arr[0].split(' ').join('');
    let timePart: string = arr[1].split(' ').join('');
    // Ensure seconds
    if (timePart.length === 5) {
      timePart = timePart + ':00';
    }
    return [datePart, timePart];
  }

  private cleanScheduleList(schedules: Schedule[]): Schedule[] {
    const result: Schedule[] = [];
    for (let i = 0; i < schedules.length; i++) {
      const s: Schedule = schedules[i];
      const cleaned: ScheduleContent = {
        title: s.content.title,
        begin_time: this.cleanTimeArr(s.content.begin_time),
        end_time: this.cleanTimeArr(s.content.end_time),
        location: s.content.location,
        repeat: s.content.repeat,
        description: s.content.description
      };
      const cleanedSchedule: Schedule = {
        id: s.id,
        timestamp: s.timestamp,
        type: s.type,
        content: cleaned
      };
      result.push(cleanedSchedule);
    }
    return result;
  }

  private normalizeUrl(url: string): string {
    // Only bare /schedule needs trailing slash; sub-routes like /schedule/quantity do NOT
    if (url === '/schedule') {
      return '/schedule/';
    }
    return url;
  }

  private appendUserId(url: string): string {
    if (this.userId.length === 0) return url;
    if (url.indexOf('?') >= 0) {
      return url + '&user_id=' + this.userId;
    }
    return url + '?user_id=' + this.userId;
  }

  async request(url: string, method: http.RequestMethod, data?: object): Promise<http.HttpResponse> {
    const normalized: string = this.normalizeUrl(url);
    const withUserId: string = this.appendUserId(normalized);
    const fullUrl: string = BASE_URL + withUserId;
    const httpRequest = http.createHttp();
    const options: http.HttpRequestOptions = {
      method: method,
      header: {
        'Content-Type': 'application/json',
        'Cookie': this.cookie
      },
      expectDataType: http.HttpDataType.STRING
    };
    if (data) {
      options.extraData = JSON.stringify(data);
    }
    console.info('HTTP_DEBUG: ' + method + ' ' + fullUrl + ' Cookie=[' + this.cookie + ']');
    const response = await httpRequest.request(fullUrl, options);
    httpRequest.destroy();
    return response;
  }

  parseResult<T>(response: http.HttpResponse): T {
    const raw = response.result;
    if (typeof raw === 'string') {
      return JSON.parse(raw) as T;
    }
    return raw as T;
  }

  private parseWithSuccess<T>(response: http.HttpResponse): T {
    const raw = response.result;
    let obj: Record<string, Object>;
    if (typeof raw === 'string') {
      obj = JSON.parse(raw) as Record<string, Object>;
    } else {
      obj = raw as Record<string, Object>;
    }
    // Inject 'success' based on HTTP status if backend didn't return it
    const keys: string[] = Object.keys(obj);
    let hasSuccess: boolean = false;
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] === 'success') {
        hasSuccess = true;
        break;
      }
    }
    if (!hasSuccess) {
      obj['success'] = (response.responseCode >= 200 && response.responseCode < 300);
    }
    return obj as T;
  }

  async post(url: string, data: object): Promise<http.HttpResponse> {
    return this.request(url, http.RequestMethod.POST, data);
  }

  async get(url: string): Promise<http.HttpResponse> {
    return this.request(url, http.RequestMethod.GET);
  }

  async put(url: string, data: object): Promise<http.HttpResponse> {
    return this.request(url, http.RequestMethod.PUT, data);
  }

  async delete(url: string): Promise<http.HttpResponse> {
    return this.request(url, http.RequestMethod.DELETE);
  }

  // ==================== Auth ====================

  async login(username: string, password: string | number): Promise<AuthResponse> {
    const data: AuthRequest = { username, password };
    const response = await this.post('/auth/login', data);
    const result: AuthResponse = this.parseResult<AuthResponse>(response);
    if (result.success) {
      let cookieStr: string = '';
      try {
        // response.cookies returns Netscape cookie file format (tab-separated):
        // domain \t tailmatch \t path \t secure \t expiry \t name \t value
        const rawCookies: string = response.cookies ?? '';
        console.info('COOKIE_DEBUG raw: [' + rawCookies + ']');
        if (rawCookies.length > 0) {
          const cookiePairs: string[] = [];
          const lines: string[] = rawCookies.split('\n');
          for (let i = 0; i < lines.length; i++) {
            const line: string = lines[i].trim();
            if (line.length === 0) continue;
            const fields: string[] = line.split('\t');
            // Netscape format: 7 tab-separated fields, name at index 5, value at index 6
            if (fields.length >= 7) {
              const name: string = fields[5];
              const value: string = fields[6];
              cookiePairs.push(name + '=' + value);
            }
          }
          cookieStr = cookiePairs.join('; ');
        }
      } catch (e) {
        cookieStr = '';
      }
      // Extract user_id from already-parsed result
      const uid: string = result.user_id ? result.user_id.toString() : '';
      this.userId = uid;
      console.info('COOKIE_DEBUG final cookie: [' + cookieStr + '] userId: [' + uid + ']');
      this.cookie = cookieStr;
      await preferencesUtil.saveLoginInfo(username, cookieStr, uid);
    }
    return result;
  }

  async register(username: string, password: string | number): Promise<AuthResponse> {
    const data: AuthRequest = { username, password };
    const response = await this.post('/auth/register', data);
    return this.parseResult<AuthResponse>(response);
  }

  // ==================== Schedule ====================

  async getSchedules(): Promise<ScheduleListResponse> {
    const response = await this.get('/schedule');
    console.info('SCHEDULE_DEBUG getSchedules code=' + response.responseCode);
    return this.parseWithSuccess<ScheduleListResponse>(response);
  }

  async getScheduleDetail(id: number): Promise<ScheduleDetailResponse> {
    const response = await this.get(`/schedule/${id}`);
    return this.parseWithSuccess<ScheduleDetailResponse>(response);
  }

  async createSchedule(schedules: Schedule[]): Promise<ScheduleCreateResponse> {
    const cleaned: Schedule[] = this.cleanScheduleList(schedules);
    const reqBody: ScheduleCreateRequest = { schedules: cleaned };
    console.info('SCHEDULE_DEBUG create: ' + JSON.stringify(reqBody));
    const response = await this.post('/schedule', reqBody);
    console.info('SCHEDULE_DEBUG create response code=' + response.responseCode + ' body=' + (response.result as string));
    return this.parseWithSuccess<ScheduleCreateResponse>(response);
  }

  async updateSchedule(id: number, schedule: Schedule): Promise<ScheduleSimpleResponse> {
    const cleanedList: Schedule[] = this.cleanScheduleList([schedule]);
    const reqBody: ScheduleUpdateRequest = { schedule: cleanedList[0] };
    console.info('SCHEDULE_DEBUG update: ' + JSON.stringify(reqBody));
    const response = await this.put(`/schedule/${id}`, reqBody);
    return this.parseWithSuccess<ScheduleSimpleResponse>(response);
  }

  async deleteSchedule(id: number): Promise<ScheduleSimpleResponse> {
    const response = await this.delete(`/schedule/${id}`);
    return this.parseWithSuccess<ScheduleSimpleResponse>(response);
  }

  async archiveSchedule(id: number): Promise<ScheduleSimpleResponse> {
    const response = await this.get(`/schedule/archive/${id}`);
    return this.parseWithSuccess<ScheduleSimpleResponse>(response);
  }

  async getScheduleQuantity(): Promise<QuantityResponse> {
    const response = await this.get('/schedule/quantity');
    return this.parseWithSuccess<QuantityResponse>(response);
  }

  // ==================== DeepSeek AI ====================

  async parseWithAI(userInput: string): Promise<string> {
    const httpRequest = http.createHttp();
    const systemPrompt: string = `你是一个日程解析助手。用户会输入一段自然语言描述，你需要从中提取日程信息并返回严格的JSON格式（不要包含任何其他文字）：
{
  "title": "任务标题",
  "begin_time": "YYYY-MM-DD HH:mm",
  "end_time": "YYYY-MM-DD HH:mm",
  "location": "地点（没有则为空字符串）",
  "repeat": "none/daily/weekly/monthly（默认none）",
  "description": "补充描述（没有则为空字符串）",
  "type": "todo/meeting/reminder（根据语义判断，默认todo）"
}
如果用户没有给出具体日期，请基于"今天"来推断。如果没有明确结束时间，默认设为开始时间1小时后。只返回JSON，不要其他文字。`;

    const sysMsg: DeepSeekMessage = { role: 'system', content: systemPrompt };
    const userMsg: DeepSeekMessage = { role: 'user', content: userInput };
    const reqBody: DeepSeekRequestBody = {
      model: 'deepseek-chat',
      messages: [sysMsg, userMsg],
      temperature: 0.3
    };
    const body: string = JSON.stringify(reqBody);

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`
      },
      extraData: body,
      expectDataType: http.HttpDataType.STRING
    };

    const response = await httpRequest.request(DEEPSEEK_API_URL, options);
    httpRequest.destroy();
    const raw = response.result;
    const parsed: DeepSeekResponse = typeof raw === 'string' ? JSON.parse(raw) as DeepSeekResponse : raw as DeepSeekResponse;
    return parsed.choices[0].message.content;
  }
}

const httpUtil = new HttpUtil();
export default httpUtil;
