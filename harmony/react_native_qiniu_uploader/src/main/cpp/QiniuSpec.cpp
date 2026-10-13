//
// Created on 2024/11/12.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

// NOTE: This entire file should be codegen'ed.

#include "QiniuSpec.h"

using namespace rnoh;
using namespace facebook;

static jsi::Value __hostFunction_NativeQiniuCxxModuleSpecJSI_startTask(jsi::Runtime &rt,
                                                                              react::TurboModule &turboModule,
                                                                              const jsi::Value *args, size_t count) {
    return jsi::Value(static_cast<ArkTSTurboModule &>(turboModule).callAsync(rt, "startTask", args, count));
}

static jsi::Value __hostFunction_NativeQiniuCxxModuleSpecJSI_resumeTask(jsi::Runtime &rt,
                                                                              react::TurboModule &turboModule,
                                                                              const jsi::Value *args, size_t count) {
    return jsi::Value(static_cast<ArkTSTurboModule &>(turboModule).call(rt, "resumeTask", args, count));
}

static jsi::Value __hostFunction_NativeQiniuCxxModuleSpecJSI_pauseTask(jsi::Runtime &rt,
                                                                              react::TurboModule &turboModule,
                                                                              const jsi::Value *args, size_t count) {
    return jsi::Value(static_cast<ArkTSTurboModule &>(turboModule).call(rt, "pauseTask", args, count));
}

static jsi::Value __hostFunction_NativeQiniuCxxModuleSpecJSI_addListener(jsi::Runtime &rt,
                                                                         react::TurboModule &turboModule,
                                                                         const jsi::Value *args, size_t count) {
    return jsi::Value(static_cast<ArkTSTurboModule &>(turboModule).call(rt, "addListener", args, count));
}
static jsi::Value __hostFunction_NativeQiniuCxxModuleSpecJSI_removeListeners(jsi::Runtime &rt,
                                                                             react::TurboModule &turboModule,
                                                                             const jsi::Value *args, size_t count) {
    return jsi::Value(static_cast<ArkTSTurboModule &>(turboModule).call(rt, "removeListeners", args, count));
}


NativeQiniuSpecJSI::NativeQiniuSpecJSI(const ArkTSTurboModule::Context ctx, const std::string name)
    : ArkTSTurboModule(ctx, name) {
    methodMap_["startTask"] = MethodMetadata{1, __hostFunction_NativeQiniuCxxModuleSpecJSI_startTask};
    methodMap_["resumeTask"] = MethodMetadata{0, __hostFunction_NativeQiniuCxxModuleSpecJSI_resumeTask};
    methodMap_["pauseTask"] = MethodMetadata{0, __hostFunction_NativeQiniuCxxModuleSpecJSI_pauseTask};
    methodMap_["addListener"] = MethodMetadata{1, __hostFunction_NativeQiniuCxxModuleSpecJSI_addListener};
    methodMap_["removeListeners"] = MethodMetadata{1, __hostFunction_NativeQiniuCxxModuleSpecJSI_removeListeners};
}