package cn.cainiaoshicai.qiniu;

import static cn.cainiaoshicai.qiniu.utils.AppConstant.CODE;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.MSG;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.ON_COMPLETE;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.ON_ERROR;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.ON_PROGRESS;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.PERCENT;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.QN_EVENT;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.TASK_ID;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.TYPE;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.kFail;
import static cn.cainiaoshicai.qiniu.utils.AppConstant.kSuccess;
import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

import java.io.File;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.qiniu.android.common.FixedZone;
import com.qiniu.android.common.Zone;
import com.qiniu.android.storage.Configuration;
import com.qiniu.android.storage.FileRecorder;
import com.qiniu.android.storage.GlobalConfiguration;
import com.qiniu.android.storage.KeyGenerator;
import com.qiniu.android.storage.Recorder;
import com.qiniu.android.storage.UpCancellationSignal;
import com.qiniu.android.storage.UpCompletionHandler;
import com.qiniu.android.storage.UpProgressHandler;
import com.qiniu.android.storage.UploadManager;
import com.qiniu.android.storage.UploadOptions;

import android.annotation.SuppressLint;
import android.net.Uri;
import android.text.TextUtils;
import androidx.annotation.Nullable;
import cn.cainiaoshicai.qiniu.interfacev1.IQNEngineEventHandler;
import cn.cainiaoshicai.qiniu.utils.ContentUriUtil;
import cn.cainiaoshicai.qiniu.utils.FileUtil;

/**
 * QiniuModule
 *
 * @author gufei
 * @version 1.0
 * @createDate 2018/4/20
 * @lastUpdate 2018/4/20
 */
public class QiniuModule extends ReactContextBaseJavaModule {

    private String TAG = this.getClass().getSimpleName();
    private ReactApplicationContext context;

    private UploadManager uploadManager;
    private String id;
    private String filePath;
    private String upKey;
    private String upToken;
    private int fixedZone;
    private boolean isTaskPause;

    public QiniuModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;
        GlobalConfiguration.getInstance().isDnsOpen = true;
        GlobalConfiguration.getInstance().udpDnsIpv4Servers = new String[]{
                "180.76.76.76",   //百度  IPV4 dns服务器
                "223.5.5.5",      //阿里  IPV4 dns服务器
                "119.29.29.29",   //腾讯  IPV4 dns服务器
                "114.114.114.114",//114  IPV4 dns服务器
                "8.8.8.8"         //谷歌  IPV4 dns服务器
        };
        GlobalConfiguration.getInstance().dohEnable = false;
    }

    @Override
    public String getName() {
        return "RCTQiniu";
    }

    private IQNEngineEventHandler engineEventHandler = new IQNEngineEventHandler() {

        @Override
        public void onProgress(final String code, final String msg, final String percent) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    WritableMap map = Arguments.createMap();
                    map.putString(TYPE, ON_PROGRESS);
                    map.putString(CODE, code);
                    map.putString(MSG, msg);
                    map.putString(PERCENT, percent);
                    commonEvent(map);
                }
            });
        }

        @Override
        public void onComplete(final String code, final String msg) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    WritableMap map = Arguments.createMap();
                    map.putString(TYPE, ON_COMPLETE);
                    map.putString(CODE, code);
                    map.putString(MSG, msg);
                    commonEvent(map);
                }
            });
        }

        @Override
        public void onError(final String code, final String msg) {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    WritableMap map = Arguments.createMap();
                    map.putString(TYPE, ON_ERROR);
                    map.putString(CODE, code);
                    map.putString(MSG, msg);
                    commonEvent(map);
                }
            });
        }
    };

    /**
     * 设置待上传文件的参数
     *
     * @param options 上传数据的可选参数
     */
    @ReactMethod
    public void setParams(final ReadableMap options) {
        id = options.getString("id");
        filePath = options.getString("filePath");
        upKey = options.getString("upKey");
        upToken = options.getString("upToken");
        fixedZone = options.getInt("zone");
        this.uploadManager = new UploadManager(config());
    }

    @ReactMethod
    public void startTask() {
        if (checkParams()) {
            uploadTask();
        }
    }

    @ReactMethod
    public void resumeTask() {
        this.isTaskPause = false;
        uploadTask();
    }

    @ReactMethod
    public void pauseTask() {
        this.isTaskPause = true;
    }

    private Configuration config() {

        String dirPath = FileUtil.getWorkFolder();
        Recorder recorder = null;
        try {
            recorder = new FileRecorder(dirPath);
        } catch (Exception e) {
            e.printStackTrace();
        }

        // 默认使用key的url_safe_base64编码字符串作为断点记录文件的文件名
        // 避免记录文件冲突（特别是key指定为null时），也可自定义文件名(下方为默认实现)
        KeyGenerator keyGen = new KeyGenerator() {
            public String gen(String key, File file) {
                // 不必使用url_safe_base64转换，uploadManager内部会处理
                // 该返回值可替换为基于key、文件内容、上下文的其它信息生成的文件名
                return key + "_._" + new StringBuffer(file.getAbsolutePath()).reverse();
            }

            @Override
            public String gen(String key, String sourceId) {
                return null;
            }
        };
        Configuration config = new Configuration.Builder()
                .chunkSize(512 * 1024)        // 分片上传时，每片的大小。 默认256K
                .connectTimeout(10)           // 链接超时。默认10秒
                .useHttps(true)               // 是否使用https上传域名
                .responseTimeout(60)          // 服务器响应超时。默认60秒
                .recorder(recorder, keyGen)   // recorder分片上传时，已上传片记录器。默认null, keyGen 分片上传时，生成标识符，用于片记录器区分是那个文件的上传记录
                .zone(fixedZone())// 设置区域，指定不同区域的上传域名、备用域名、备用IP。
                .build();
        return config;
    }

    private Zone fixedZone() {
        Zone fixedZone = FixedZone.zone0;
        switch (this.fixedZone) {
            case 1:
                fixedZone = FixedZone.zone0;
                break;
            case 2:
                fixedZone = FixedZone.zone1;
                break;
            case 3:
                fixedZone = FixedZone.zone2;
                break;
            case 4:
                fixedZone = FixedZone.zoneNa0;
                break;
        }
        return fixedZone;
    }

    private boolean checkParams() {

        boolean pass = true;

        String msg = "check params pass";
        if (TextUtils.isEmpty(filePath)) {
            msg = "filePath can not be nil";
            pass = false;
        } else if (TextUtils.isEmpty(upKey)) {
            msg = "upKey can not be nil";
            pass = false;
        } else if (TextUtils.isEmpty(upToken)) {
            msg = "upToken can not be nil";
            pass = false;
        }

        if (!pass)
            engineEventHandler.onError(kFail, msg);

        if (pass) {
            if (filePath.startsWith("file://"))
                filePath = filePath.replaceFirst("file://", "");
            else if (filePath.startsWith("content://"))
                filePath = ContentUriUtil.getPath(context, Uri.parse(filePath));
        }

        return pass;
    }

    private final UpCompletionHandler upCompletionHandler = (key, info, response) -> {
        //res包含hash、key等信息，具体字段取决于上传策略的设置
        if (info.isOK()) {
            engineEventHandler.onComplete(kSuccess, "上传成功");
        } else {

            //如果失败，这里可以把info信息上报自己的服务器，便于后面分析上传错误原因
            engineEventHandler.onError(String.valueOf(info.statusCode), info.error);
        }
    };
    private final UpProgressHandler upProgressHandler = (key, percent) -> {
        @SuppressLint("DefaultLocale") String per = String.format("%.2f", percent);
        engineEventHandler.onProgress(kSuccess, key, per);
    };
    private final UpCancellationSignal upCancellationSignal = new UpCancellationSignal() {
        @Override
        public boolean isCancelled() {
            return isTaskPause;
        }
    };

    private void uploadTask() {

        uploadManager.put(filePath, upKey, upToken, upCompletionHandler,
                new UploadOptions(null, null, false, upProgressHandler, upCancellationSignal));
    }

    @ReactMethod
    public void addListener(String eventName) {
        // Keep: Required for RN built in Event Emitter Calls.
    }

    @ReactMethod
    public void removeListeners(Integer count) {
        // Keep: Required for RN built in Event Emitter Calls.
    }

    private void commonEvent(WritableMap map) {
        map.putString(TASK_ID, id);
        sendEvent(getReactApplicationContext(), QN_EVENT, map);
    }

    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }
}
