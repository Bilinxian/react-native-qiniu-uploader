//
// Created on 2024/11/12.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#include "QiniuPackage.h"
#include "QiniuSpec.h"


using namespace rnoh;
using namespace facebook;

class QiniuPackageFactoryDelegate : public TurboModuleFactoryDelegate {
    
    public:
    SharedTurboModule createTurboModule(Context ctx, const std::string &name) const override {
        if (name == "Qiniu") {
            return std::make_shared<NativeQiniuSpecJSI>(ctx, name);
        }
        return nullptr;
    };
};

std::unique_ptr<TurboModuleFactoryDelegate> QiniuPackage::createTurboModuleFactoryDelegate() {
    return std::make_unique<QiniuPackageFactoryDelegate>();
}


