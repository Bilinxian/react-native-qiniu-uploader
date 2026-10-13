import { TurboModule, TurboModuleContext } from "@rnoh/react-native-openharmony/ts";

import { createMultipartUploadV2Task, UploadFile, UploadTask, MultipartUploadV2Context } from '@qiniu/upload';

interface uploadParams {
  id: string;
  filePath: string;
  upKey: string;
  upToken: string;
  isAsyncTask?: boolean;
}

/**
 * start() 返回的是 SDK 内部联合类型 Result，ArkTS 不能直接访问联合成员上的差异字段。
 * 这里用扁平 optional 结构做断言，避免 union 属性访问报错。
 */
interface UploadStartResult {
  result?: Object;
  error?: Error;
  canceled?: boolean;
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

  async startUploadTask(file: UploadFile, token: string, taskId?: string, isAsyncTask?: boolean): Promise<string> {

    if (this.uploadTask) {
      await this.uploadTask.cancel();
    }
    this.uploadTask = createMultipartUploadV2Task(this.ctx.uiAbilityContext, file, {tokenProvider: async () => token});

    this.uploadTask.onComplete((result, context) => {
      this.ctx.rnInstance.emitDeviceEvent("qiniuEvent", {
        type: "onComplete",
        code: "0",
        msg: "",
        id: taskId ?? ''
      })
    })
    this.uploadTask.onError((error, context) => {
      this.ctx.rnInstance.emitDeviceEvent("qiniuEvent", { type: "onError", code: error?.name, msg: error?.message })
    })

    this.uploadTask.onProgress((progress, context) => {
      this.ctx.rnInstance.emitDeviceEvent("qiniuEvent", {
        type: "onProgress",
        code: "0",
        msg: "",
        percent: progress.percent
      })
    })

    if (!isAsyncTask) {
      this.uploadTask?.start()
      return Promise.resolve("")
    }

    return new Promise((resolve, reject) => {
      this.uploadTask?.start().then((res) => {
        // SDK Result = SuccessResult | ErrorResult | CanceledResult，需断言后再读差异字段
        const result = res as UploadStartResult
        if (result.error != undefined) {
          reject(result.error.message)
          return
        }
        if (result.canceled) {
          reject("上传已取消")
          return
        }
        resolve("上传成功")
      }).catch((error: Error) => reject(error.message))
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
