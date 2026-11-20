import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================================
// 正式签名（R1）
// ============================================================================
// 为什么必须换掉 debug 签名：debug keystore 的证书有效期只有 1 年（本机生成的
// 那张到 2027-10 过期）。过期后**同一包名无法覆盖安装**，用户只能卸载重装，
// 而卸载会连同数据库一起删掉 —— 对这个「数据只存本机」的 app 是灾难。
//
// 口令与别名来自 android/key.properties（已在 .gitignore 里，不进仓库）；
// 文件缺失时直接让构建失败，绝不回落到 debug 签名悄悄出一个装不上的包。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (!keystorePropertiesFile.exists()) {
    throw GradleException(
        "缺少 android/key.properties：release 必须用正式签名（详见文件顶部说明）。",
    )
}
FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }

android {
    namespace = "com.efficiency.app.efficiency_app"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion intentionally omitted: this project has no native code
    // (no src/main/jni, no CMakeLists.txt, no FFI). Leaving the template
    // default made Flutter require NDK 28.2.13676358 and abort the build with
    // "Package ndk not found" / "Package 28.2.13676358 not found", which would
    // otherwise force a ~2 GB NDK download for nothing.
    // Re-add: ndkVersion = flutter.ndkVersion   (when native code is needed)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 用到 java.time（API 26+ 才原生有），
        // minSdk 低于 26 时必须开启 desugaring，否则运行期 NoClassDefFoundError。
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.efficiency.app.efficiency_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // 版本号写死（R1 任务 1）：不再跟着 pubspec.yaml 漂。
        // versionCode 每次发版必须 +1，否则 Android 拒绝覆盖安装；
        // split-per-abi 时 Flutter 会再叠加 1000*abiVersion，属预期行为。
        versionCode = 8
        versionName = "1.8.0"
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            // 正式签名（替代原来的 debug）
            signingConfig = signingConfigs.getByName("release")
            // R8：删无用代码 + 资源。真正的风险不是体积，是反射：
            // WorkManager/Room 按类名实例化，规则见 proguard-rules.pro。
            isMinifyEnabled = true
            isShrinkResources = true
            // 显式指定混淆规则：WorkManager 的 Room 数据库靠反射建实例，
            // 类名被 R8 混淆后会崩（见 proguard-rules.pro 顶部说明）。
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Java 8+ API 脱糖（flutter_local_notifications 的 java.time 依赖它）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // 闹钟原生层用到 NotificationCompat / NotificationManagerCompat / ContextCompat。
    // 这几个类在 androidx.core 里；它虽然已由 flutter_embedding 传递引入，
    // 但「靠传递依赖编译」是易碎做法，这里显式声明（版本与传递版本一致，不产生冲突）。
    implementation("androidx.core:core:1.13.1")

    // T19 R1：B 档（无精确权限）漏响兜底用 WorkManager 的周期任务。
    // 选 2.9.1 的理由：稳定版、传递依赖最少（room-runtime / lifecycle），
    // 且已在阿里云 google 镜像上确认可下载（pom HTTP 200）。
    // 周期任务最小值 15 分钟由平台决定，见 AlarmScanScheduler.INTERVAL_MINUTES。
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}

flutter {
    source = "../.."
}
