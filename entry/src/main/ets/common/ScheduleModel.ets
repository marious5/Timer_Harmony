export interface ScheduleContent {
  title: string;
  begin_time: string[];
  end_time: string[];
  location: string;
  repeat: string;
  description: string;
}

export interface Schedule {
  id: number;
  timestamp: number | string;
  type: string;
  content: ScheduleContent;
  finished?: boolean;
  archived?: boolean;
  archive?: boolean;
}

export interface ScheduleListResponse {
  schedules: Schedule[];
  success: boolean;
  error?: string;
}

export interface ScheduleDetailResponse {
  schedule: Schedule;
  success: boolean;
  error?: string;
}

export interface ScheduleCreateResponse {
  ids: number[];
  success: boolean;
  error?: string;
}

export interface ScheduleSimpleResponse {
  success: boolean;
  error?: string;
}

export interface QuantityResponse {
  quantity: number;
  success: boolean;
  error?: string;
}
