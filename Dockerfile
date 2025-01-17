FROM debian:stretch

SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y \
    curl \
    git \
    libgl1-mesa-glx \
    openjdk-8-jdk-headless \
    unzip \
    wget

ENV ANDROID_HOME /opt/android-sdk-linux
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH $PATH:/usr/lib/jvm/java-8-openjdk-amd64/bin

# Download Android SDK tools into $ANDROID_HOME
RUN cd /opt && wget -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O android-sdk-tools.zip && \
    unzip -q android-sdk-tools.zip && mkdir -p "$ANDROID_HOME" && mv tools/ "$ANDROID_HOME"/tools/ && \
    rm android-sdk-tools.zip

ENV PATH "$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools"

# Accept licenses before installing components
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --licenses

RUN sdkmanager "platform-tools"

# list all platforms, sort them in descending order, take the newest 8 versions and install them
RUN sdkmanager $(sdkmanager --list 2> /dev/null | grep platforms | awk -F' ' '{print $1}' | sort -nr -k2 -t- | head -8)
# list all build-tools, sort them in descending order and install them
RUN sdkmanager $(sdkmanager --list 2> /dev/null | grep build-tools | awk -F' ' '{print $1}' | sort -nr -k2 -t \; | uniq)

# install Appium
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g appium --unsafe-perm=true

RUN sdkmanager emulator && \
    sdkmanager "system-images;android-29;google_apis_playstore;x86" && \
    echo no | avdmanager create avd -n emu_29 -k "system-images;android-29;google_apis_playstore;x86"

# install gcloud
RUN wget -q https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-316.0.0-linux-x86_64.tar.gz -O g.tar.gz && \
    tar xf g.tar.gz && \
    rm g.tar.gz && \
    mv google-cloud-sdk /opt/google-cloud-sdk && \
    /opt/google-cloud-sdk/install.sh -q && \
    /opt/google-cloud-sdk/bin/gcloud config set component_manager/disable_update_check true
# add gcloud SDK to path
ENV PATH="${PATH}:/opt/google-cloud-sdk/bin/"

## Danger-kotlin dependencies

# nvm environment variables
ENV NVM_DIR=/usr/local/nvm \
    NODE_VERSION=12.2.0

# install nvm
# https://github.com/creationix/nvm#install-script
RUN mkdir $NVM_DIR && \
    curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/v0.37.2/install.sh | bash

RUN source $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default

# add node and npm to path so the commands are available
ENV NODE_PATH=$NVM_DIR/v$NODE_VERSION/lib/node_modules \
    PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# install make which is needed in danger-kotlin install phase
RUN apt-get update && apt-get install -y \
    make

# install danger-js which is needed for danger-kotlin to work
RUN npm install -g danger@10.2.1

# install kotlin compiler
RUN curl -o kotlin-compiler.zip -L https://github.com/JetBrains/kotlin/releases/download/v1.4.10/kotlin-compiler-1.4.10.zip && \
    unzip -d /usr/local/ kotlin-compiler.zip && \
    rm -rf kotlin-compiler.zip

# install danger-kotlin
RUN git clone https://github.com/danger/kotlin.git _danger-kotlin && \
    cd _danger-kotlin && git checkout 0.7.1 && \
    make install  && \
    cd ..  && \
    rm -rf _danger-kotlin

# setup environment variables
ENV PATH=$PATH:/usr/local/kotlinc/bin

VOLUME /root/.gradle