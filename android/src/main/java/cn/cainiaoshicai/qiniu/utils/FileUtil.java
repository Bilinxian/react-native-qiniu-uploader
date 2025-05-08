package cn.cainiaoshicai.qiniu.utils;

import android.content.Context;

public class FileUtil {

    private String TAG = this.getClass().getSimpleName();

    private static final String DATA_DIRECTORY = "/qiniu_data/" ;

    public static String getWorkFolder(Context context) {
        return context.getFilesDir().getAbsolutePath() + DATA_DIRECTORY;
    }

}
