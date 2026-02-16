# build linux & android app
FROM ubuntu:22.04 AS builder

# prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# env
ENV GO_VERSION=1.24.0
ENV GOOS=linux
ENV GOARCH=amd64

# install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    bash \
    zip \
    git \
    wget \
    xz-utils \
    # linux
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev \
    libsecret-1-dev \
    libayatana-appindicator3-dev \
    lld \
    # egl
    mesa-utils \
    # android
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

# flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# golang
RUN wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz

# android sdk command line tools
RUN mkdir -p /usr/local/android-sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d /usr/local/android-sdk/cmdline-tools && \
    mv /usr/local/android-sdk/cmdline-tools/cmdline-tools /usr/local/android-sdk/cmdline-tools/latest && \
    rm cmdline-tools.zip

# env variables for flutter, go, and android sdk
ENV ANDROID_SDK_ROOT=/usr/local/android-sdk
ENV ANDROID_HOME=/usr/local/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="/usr/local/go/bin:/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:/usr/local/android-sdk/cmdline-tools/latest/bin:/usr/local/android-sdk/platform-tools:${PATH}"

# accept android sdk licenses and install required sdk components
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# precache flutter artifacts for linux and android
RUN flutter precache --linux

# set working directory
WORKDIR /app

# install flutter dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# verify flutter setup (can remove)
RUN flutter doctor -v

# copy the rest of the app source code
COPY . .

# build the flutter linux app
RUN flutter build linux --release

# build the flutter android app
RUN flutter build apk --release

# build rpc socket
WORKDIR /app/rpc_hyjacker
RUN go build -o rpc main.go

RUN mv /app/rpc_hyjacker/rpc /app/build/linux/x64/release/bundle/rpc

# zip up the built app and rpc
WORKDIR /app/build/linux/x64/release/bundle
RUN zip -r /app/app-linux.zip .

# zip up the built android apk
WORKDIR /app/build/app/outputs/flutter-apk
RUN zip -r /app/app-android.zip app-release.apk

# export stage - extracts just the zip files
FROM scratch AS export
COPY --from=builder /app/app-linux.zip /
COPY --from=builder /app/app-android.zip /