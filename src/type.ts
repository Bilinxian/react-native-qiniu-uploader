export type uploadParams = {
  id: string
  filePath: string
  upKey: string
  upToken: string
  isAsyncTask?: boolean
}

export type onEvent = {
  onError: (event: onNativeEvent) => void;
  onComplete: (event: onNativeEvent) => void;
  onProgress: (event: onNativeEvent) => void;
};
export type onNativeEvent = {
  type: 'onError' | 'onComplete' | 'onProgress';
  code: string;
  msg: string;
  id?: string
  percent?: string | number
};