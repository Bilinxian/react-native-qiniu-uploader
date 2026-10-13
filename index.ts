import {NativeEventEmitter, EmitterSubscription} from 'react-native';

import Qiniu from './src/index'
import {uploadParams, onNativeEvent, onEvent} from './src/type'

const qnEmitter = new NativeEventEmitter(Qiniu);

let listener: EmitterSubscription | undefined;

export const QNEngine = {

  startTask(params: uploadParams): Promise<string> {
    const uploadParams = {...params}
    if (undefined === uploadParams.isAsyncTask) {
      uploadParams.isAsyncTask = false
    }
    return Qiniu.startTask(uploadParams)
  },
  resumeTask() {
    Qiniu.resumeTask()
  },
  pauseTask() {
    Qiniu.pauseTask()
  },
  eventEmitter({onComplete, onError, onProgress}: onEvent) {
    this.removeEmitter();
    listener = qnEmitter.addListener('qiniuEvent', (event: onNativeEvent) => {
        switch (event.type) {
          case 'onProgress':
            onProgress && onProgress(event)
            break
          case 'onError':
            onError && onError(event)
            break
          case 'onComplete':
            onComplete && onComplete(event)
            break
        }
      }
    );
  },
  removeEmitter() {
    listener?.remove();
  }
};
