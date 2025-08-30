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

import java.io.File;
import java.util.HashMap;
import java.util.Map;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.qiniu.android.common.AutoZone;
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

public class QiniuModule extends ReactContextBaseJavaModule implements IQNEngineEventHandler {

    private String TAG = this.getClass().getSimpleName();
    private final ReactApplicationContext context;

    private UploadManager uploadManager;
    private Map<String, UploadTask> taskMap = new HashMap<>();

    public QiniuModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;
        GlobalConfiguration.getInstance().isDnsOpen = false;
        GlobalConfiguration.getInstance().udpDnsIpv4Servers = new String[]{
                "223.5.5.5",      //阿里  IPV4 dns服务器
                "119.29.29.29",   //腾讯  IPV4 dns服务器
                "114.114.114.114",//114  IPV4 dns服务器
                "180.76.76.76",   //百度  IPV4 dns服务器
                "8.8.8.8"         //谷歌  IPV4 dns服务器
        };
        GlobalConfiguration.getInstance().dohEnable = false;
        this.uploadManager = new UploadManager(config());
    }

    @Override
    public String getName() {
        return "RCTQiniu";
    }

    /**
     * 设置待上传文件的参数
     *
     * @param options 上传数据的可选参数
     */
    @ReactMethod
    public void startTask(final ReadableMap options, Promise promise) {
        String id = options.getString("id");
        String filePath = options.getString("filePath");
        String upKey = options.getString("upKey");
        String upToken = options.getString("upToken");
        boolean isAsyncTask = false;
        if (options.hasKey("isAsyncTask")) {
            isAsyncTask = options.getBoolean("isAsyncTask");
        }

        UploadTask task = new UploadTask(id, filePath, upKey, upToken);
        taskMap.put(id, task);

        if (checkParams(task)) {
            if (isAsyncTask)
                uploadTask(task, promise);
            else {
                uploadTask(task, null);
                promise.resolve("");
            }
        } else {
            promise.reject("PARAMS_ERROR", "参数校验失败");
        }
    }

    @ReactMethod
    public void resumeTask(String taskId) {
        UploadTask task = taskMap.get(taskId);
        if (task != null) {
            task.setPaused(false);
            uploadTask(task, null);
        }
    }

    @ReactMethod
    public void pauseTask(String taskId) {
        UploadTask task = taskMap.get(taskId);
        if (task != null) {
            task.setPaused(true);
        }
    }

    @ReactMethod
    public void removeTask(String taskId) {
        taskMap.remove(taskId);
    }

    private Configuration config() {
        String dirPath = FileUtil.getWorkFolder(context);
        Recorder recorder = null;
        try {
            recorder = new FileRecorder(dirPath);
        } catch (Exception e) {
            e.printStackTrace();
        }

        KeyGenerator keyGen = new KeyGenerator() {
            public String gen(String key, File file) {
                return key + "_._" + new StringBuffer(file.getAbsolutePath()).reverse();
            }

            @Override
            public String gen(String key, String sourceId) {
                return null;
            }
        };

        Configuration config = new Configuration.Builder()
                .chunkSize(512 * 1024)
                .connectTimeout(60)
                .writeTimeout(120)
                .responseTimeout(120)
                .useHttps(true)
                .recorder(recorder, keyGen)
                .zone(new AutoZone())
                .putThreshold(512 * 1024)
                .allowBackupHost(true)
                .build();
        return config;
    }

    private boolean checkParams(UploadTask task) {
        boolean pass = true;
        String msg = "check params pass";

        if (TextUtils.isEmpty(task.getFilePath())) {
            msg = "filePath can not be nil";
            pass = false;
        } else if (TextUtils.isEmpty(task.getUpKey())) {
            msg = "upKey can not be nil";
            pass = false;
        } else if (TextUtils.isEmpty(task.getUpToken())) {
            msg = "upToken can not be nil";
            pass = false;
        }

        if (!pass) {
            // 使用接口要求的方法签名
            onError(kFail, msg);
            return false;
        }

        String filePath = task.getFilePath();
        if (filePath.startsWith("file://")) {
            task.setFilePath(filePath.replaceFirst("file://", ""));
        } else if (filePath.startsWith("content://")) {
            String realPath = ContentUriUtil.getPath(context, Uri.parse(filePath));
            if (realPath != null) {
                task.setFilePath(realPath);
            }
        }

        return pass;
    }

    private void uploadTask(UploadTask task, Promise promise) {
        if (promise == null) {
            // 异步上传，通过事件回调
            uploadManager.put(task.getFilePath(), task.getUpKey(), task.getUpToken(),
                    createCompletionHandler(task),
                    new UploadOptions(null, null, false, createProgressHandler(task), createCancellationSignal(task)));
        } else {
            // 同步上传，通过Promise返回结果
            uploadManager.put(task.getFilePath(), task.getUpKey(), task.getUpToken(),
                    (key, info, response) -> {
                        if (info.isOK()) {
                            promise.resolve("上传成功");
                        } else {
                            promise.reject(String.valueOf(info.statusCode), info.error);
                        }
                    },
                    new UploadOptions(null, null, false, (key, percent) -> {}, () -> false));
        }
    }

    private UpCompletionHandler createCompletionHandler(final UploadTask task) {
        return new UpCompletionHandler() {
            @Override
            public void complete(String key, com.qiniu.android.http.ResponseInfo info, org.json.JSONObject response) {
                if (info.isOK()) {
                    // 使用包装方法发送带taskId的事件
                    sendCompleteEvent(task.getId(), kSuccess, "上传成功");
                } else {
                    // 使用包装方法发送带taskId的事件
                    sendErrorEvent(task.getId(), String.valueOf(info.statusCode), info.error);
                }
                // 上传完成后移除任务（可选）
                taskMap.remove(task.getId());
            }
        };
    }

    private UpProgressHandler createProgressHandler(final UploadTask task) {
        return new UpProgressHandler() {
            @Override
            public void progress(String key, double percent) {
                @SuppressLint("DefaultLocale") String per = String.format("%.2f", percent);
                // 使用包装方法发送带taskId的事件
                sendProgressEvent(task.getId(), kSuccess, key, per);
            }
        };
    }

    private UpCancellationSignal createCancellationSignal(final UploadTask task) {
        return new UpCancellationSignal() {
            @Override
            public boolean isCancelled() {
                return task.isPaused();
            }
        };
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
        sendEvent(getReactApplicationContext(), QN_EVENT, map);
    }

    private void sendEvent(ReactContext reactContext,
                           String eventName,
                           @Nullable WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    // 包装方法：发送进度事件（带taskId）
    private void sendProgressEvent(String taskId, String code, String msg, String percent) {
        WritableMap map = Arguments.createMap();
        map.putString(TASK_ID, taskId);
        map.putString(TYPE, ON_PROGRESS);
        map.putString(CODE, code);
        map.putString(MSG, msg);
        map.putString(PERCENT, percent);
        commonEvent(map);
    }

    // 包装方法：发送完成事件（带taskId）
    private void sendCompleteEvent(String taskId, String code, String msg) {
        WritableMap map = Arguments.createMap();
        map.putString(TASK_ID, taskId);
        map.putString(TYPE, ON_COMPLETE);
        map.putString(CODE, code);
        map.putString(MSG, msg);
        commonEvent(map);
    }

    // 包装方法：发送错误事件（带taskId）
    private void sendErrorEvent(String taskId, String code, String msg) {
        WritableMap map = Arguments.createMap();
        map.putString(TASK_ID, taskId);
        map.putString(TYPE, ON_ERROR);
        map.putString(CODE, code);
        map.putString(MSG, msg);
        commonEvent(map);
    }

    // 以下是 IQNEngineEventHandler 接口的实现（保持原有签名）
    @Override
    public void onProgress(String code, String msg, String percent) {
        // 这个方法的实现保持原有逻辑，但可能不再使用
        // 因为我们使用带taskId的包装方法
        WritableMap map = Arguments.createMap();
        map.putString(TYPE, ON_PROGRESS);
        map.putString(CODE, code);
        map.putString(MSG, msg);
        map.putString(PERCENT, percent);
        commonEvent(map);
    }

    @Override
    public void onComplete(String code, String msg) {
        // 这个方法的实现保持原有逻辑，但可能不再使用
        // 因为我们使用带taskId的包装方法
        WritableMap map = Arguments.createMap();
        map.putString(TYPE, ON_COMPLETE);
        map.putString(CODE, code);
        map.putString(MSG, msg);
        commonEvent(map);
    }

    @Override
    public void onError(String code, String msg) {
        // 这个方法的实现保持原有逻辑，但可能不再使用
        // 因为我们使用带taskId的包装方法
        WritableMap map = Arguments.createMap();
        map.putString(TYPE, ON_ERROR);
        map.putString(CODE, code);
        map.putString(MSG, msg);
        commonEvent(map);
    }

    /**
     * 内部类：封装上传任务状态
     */
    private static class UploadTask {
        private String id;
        private String filePath;
        private String upKey;
        private String upToken;
        private boolean isPaused;

        public UploadTask(String id, String filePath, String upKey, String upToken) {
            this.id = id;
            this.filePath = filePath;
            this.upKey = upKey;
            this.upToken = upToken;
            this.isPaused = false;
        }

        public String getId() {
            return id;
        }

        public String getFilePath() {
            return filePath;
        }

        public void setFilePath(String filePath) {
            this.filePath = filePath;
        }

        public String getUpKey() {
            return upKey;
        }

        public String getUpToken() {
            return upToken;
        }

        public boolean isPaused() {
            return isPaused;
        }

        public void setPaused(boolean paused) {
            isPaused = paused;
        }
    }
}
