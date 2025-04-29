import {
  NativeModules,
  NativeEventEmitter, EmitterSubscription
} from 'react-native';

const {Qiniu} = NativeModules
const qnEmitter = new NativeEventEmitter(Qiniu);
type uploadParams = {
  id: string
  filePath: string
  upKey: string
  upToken: string
}

interface EventType {
  type: 'onProgress' | 'onComplete' | 'onError';

  [key: string]: any; // 其他动态字段
}

type eventParams = {
  code: string
  msg: string
  percent?: string
}

interface EmitterParams {
  onComplete?: (event: eventParams) => void; // 根据实际数据结构调整
  onError?: (error: eventParams) => void;
  onProgress?: (event: eventParams) => void
  // 可以扩展其他事件类型
}

let listener: EmitterSubscription;

export const QNEngine = {

  startTask(params: uploadParams) {
    Qiniu.startTask(params)
  },
  resumeTask() {
    Qiniu.resumeTask()
  },
  pauseTask() {
    Qiniu.pauseTask()
  },
  eventEmitter(fnConf: EmitterParams) {
    this.removeEmitter();
    listener = qnEmitter.addListener('qiniuEvent', (event) => {
        const eventType = event.type; // 例如 'onComplete' 或 'onError'
        const callback = fnConf[eventType as keyof EmitterParams]; // 动态获取回调

        if (callback) {
          callback(event); // 执行对应的回调
        }
      }
    );
  },
  removeEmitter() {
    listener && listener.remove();
  }
};
