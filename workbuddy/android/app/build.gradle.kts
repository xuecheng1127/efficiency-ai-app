plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
