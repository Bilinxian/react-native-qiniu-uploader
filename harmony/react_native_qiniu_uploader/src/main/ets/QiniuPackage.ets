import { RNPackage, TurboModulesFactory, } from "@rnoh/react-native-openharmony/ts";
import type { TurboModule, TurboModuleContext, } from "@rnoh/react-native-openharmony/ts";
import { QiniuTurboModule } from "./QiniuTurboModule";

class QiniuTurboModulesFactory extends TurboModulesFactory {
  createTurboModule(name: string): TurboModule | null {
    if (name === "Qiniu") {
      return new QiniuTurboModule(this.ctx)
    }
    return null
  }

  hasTurboModule(name: string): boolean {
    return name === "Qiniu"
  }
}

export class QiniuPackage extends RNPackage {
  createTurboModulesFactory(ctx: TurboModuleContext): TurboModulesFactory {
    return new QiniuTurboModulesFactory(ctx)
  }
}