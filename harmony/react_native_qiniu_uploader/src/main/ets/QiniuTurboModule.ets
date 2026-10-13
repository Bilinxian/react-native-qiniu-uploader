import { TurboModule, TurboModuleContext } from "@rnoh/react-native-openharmony/ts";

import { createMultipartUploadV2Task, UploadFile, UploadTask, MultipartUploadV2Context } from '@qiniu/upload';
import {
  UploadConfig,
  isSuccessResult,
  UploadError,
  isCanceledResult
} from "@qiniu/upload/src/main/ets/components/@internal";
import { UploadContext } from "@qiniu/upload/src/main/ets/components/@internal/upload/common/context";

interface uploadParams {
  id: string;
  filePath: string;
  upKey: string;
  upToken: string;
  isAsyncTask?: boolean;
}

export class QiniuTurboModule extends TurboModule {
  protected ctx: TurboModuleContext;
  private uploadTask?: UploadTask<MultipartUploadV2Context>;

  constructor(ctx: TurboModuleContext) {
    super(ctx);
    this.ctx = ctx;
  }

  startTask(params: uploadParams): Promise<string> {
    const id = params.id;
    const filePath = params.filePath;
    const upKey = params.upKey;
    const upToken = params.upToken;
    const isAsyncTask = params.isAsyncTask;
    const file = UploadFile.fromUri(filePath)
    file.key = upKey
    return this.startUploadTask(file, upToken, id, isAsyncTask)
  }

  // startTaskFromPath(path: string, token: string, upKey: string): Promise<boolean> {
  //   const file = UploadFile.fromPath(path)
  //   file.key = upKey
  //   return this.startTask(file, token)
  // }

  async startUploadTask(file: UploadFile, token: string, taskId?: string, isAsyncTask?: boolean): Promise<string> {

    const config: UploadConfig = {
      tokenProvider: async () => await token
    }
    if (this.uploadTask) {
      await this.uploadTask.cancel();
    }
    this.uploadTask = createMultipartUploadV2Task(this.ctx.uiAbilityContext, file, config);

    this.uploadTask.onComplete((result: string, context: UploadContext) => {
      this.ctx.rnInstance.emitDeviceEvent("qiniuEvent", {
        type: "onComplete",
        code: "0",
        msg: "",
        id: taskId ?? ''
      })
    })
    this.uploadTask.onError((error: UploadError, context: UploadContext) => {
      this.ctx.rnInstance.emitDeviceEvent("qiniuEvent", { type: "onError", code: error.name, msg: error.message })
    })

    this.uploadTask.onProgress((progress, context) => {
      this.ctx.rnInstance.emitDeviceEvent("qiniuEvent", { type: "onProgress", code: "0", msg: "", percent: progress })
    })

    return new Promise((resolve, reject) => {
      this.uploadTask?.start().then(res => {
        if (isSuccessResult(res)) {
          resolve("上传成功")
          return
        }
        if (isCanceledResult(res)) {
          reject("上传已取消")
          return
        }
        reject(res)
      }).catch((error: UploadError) => reject(error.message))
    })
  }

  resumeTask() {

  }

  pauseTask() {

  }

  addListener(eventName: string): void {

  }

  removeListeners(count: number): void {

  }
}
