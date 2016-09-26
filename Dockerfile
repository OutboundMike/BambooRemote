# extend
FROM ubuntu:14.04

MAINTAINER Michael Smith (mike.smith@outboundmike.com)


ENV BAMBOO_SERVER=http://52.201.251.253:8085/agentServer/
ENV BAMBOO_VERSION=5.7.2

# update dpkg repositories
RUN apt-get update

# install critical packages
RUN apt-get --quiet --yes install libtcnative-1 nginx xclip openssl imagemagick xmlstarlet software-properties-common python-software-properties nano ssh wget curl sed ruby unzip git \
 && apt-get clean

# install Ant
RUN apt-get --quiet --yes install python-software-properties$
RUN apt-get update
RUN apt-get --quiet --yes install ant


# install java 8
RUN add-apt-repository ppa:openjdk-r/ppa
RUN apt-get update
RUN apt-get --quiet --yes install openjdk-8-jdk

# set java environment variable
RUN export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
RUN echo PATH $JAVA_HOME/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH $JAVA_HOME/bin:$PATH

# configure symbolic links for the java and javac executables
RUN update-alternatives --install /usr/bin/java java $JAVA_HOME/bin/java 20000 && update-alternatives --install /usr/bin/javac javac $JAVA_HOME/bin/javac 20000

# ------ MariaDB -----

RUN apt-get update
RUN apt-get --quiet --yes install mariadb-server


# ------ Gradle ------
ENV GRADLE_VERSION 2.5
ENV TERM dumb
ENV JAVA_OPTS -Xms256m -Xmx512m

WORKDIR /opt
RUN \
	curl -sLO https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip && \
	unzip gradle-${GRADLE_VERSION}-all.zip && \
	ln -s gradle-${GRADLE_VERSION} gradle && \
	rm gradle-${GRADLE_VERSION}-all.zip

ENV GRADLE_HOME /opt/gradle
ENV PATH $PATH:$GRADLE_HOME/bin

RUN sh -c 'echo "deb https://sdkrepo.atlassian.com/debian/ stable contrib" >>/etc/apt/sources.list' && \
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B07804338C015B73 && \
  apt-get install --quiet --yes --no-install-recommends apt-transport-https && \
  apt-get update && \
  apt-get install --quiet --yes --no-install-recommends atlassian-plugin-sdk && \
  atlas-version && \
  mkdir -p /root/bamboo-agent-home/ 

RUN wget http://mirror.serversupportforum.de/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz && \
  tar -zxf apache-maven-3.3.9-bin.tar.gz && \
  sudo cp -R apache-maven-3.3.9 /usr/local && \
  sudo ln -s /usr/local/apache-maven-3.3.9/bin/mvn /usr/bin/mvn
  
RUN echo ${BAMBOO_SERVER}/agentInstaller/atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar
RUN wget ${BAMBOO_SERVER}/agentInstaller/atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar 
RUN cp atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar /root
RUN mkdir -p /root/bamboo-agent-home/bin/
RUN touch /root/bamboo-agent-home/bin/bamboo-capabilities.properties
RUN echo 'system.git.executable=/usr/bin/git' >> /root/bamboo-agent-home/bin/bamboo-capabilities.properties
RUN echo 'atlassian.sdk=6.1.0' >> /root/bamboo-agent-home/bin/bamboo-capabilities.properties
RUN echo 'system.builder.mvn3.atlas-mvn\ 3=/usr/share/atlassian-plugin-sdk-6.1.0/apache-maven-3.2.1' >> /root/bamboo-agent-home/bin/bamboo-capabilities.properties
RUN echo 'system.builder.mvn3.atlas-mvn\ 3.2=/usr/share/atlassian-plugin-sdk-6.1.0/apache-maven-3.2.1' >> /root/bamboo-agent-home/bin/bamboo-capabilities.properties
RUN echo 'system.builder.mvn3.atlas-mvn\ 3.2.1=/usr/share/atlassian-plugin-sdk-6.1.0/apache-maven-3.2.1' >> /root/bamboo-agent-home/bin/bamboo-capabilities.properties
RUN echo 'system.builder.mvn3.Maven\ 3=/usr/bin/mvn' >> /root/bamboo-agent-home/bin/bamboo-capabilities.properties

# ------ Basic modules ------
RUN dpkg --add-architecture i386 && \
	apt-get update && \
	apt-get install -y \
	build-essential \
	software-properties-common \
	git \
	python \
	python-dev \
	python-pip \
	unzip \
	vim \
	curl \
	ant \
	libc6-i386 lib32stdc++6 lib32gcc1 lib32ncurses5 lib32z1 \
	libjpeg8-dev zlib1g-dev && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*


# ------ Python dependencies ------
RUN pip install Pillow

# -----AWSCLI-------
RUN pip install awscli

#
CMD java -jar atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar ${BAMBOO_SERVER}

# download tomcat 8
RUN wget --no-verbose -O /tmp/apache-tomcat-8.5.5.tar.gz http://www-eu.apache.org/dist/tomcat/tomcat-8/v8.5.5/bin/apache-tomcat-8.5.5.tar.gz

# install tomcat 8
RUN tar xzf /tmp/apache-tomcat-8.5.5.tar.gz -C /opt/

ENV CATALINA_HOME /opt/apache-tomcat-8.5.5
ENV PATH $CATALINA_HOME/bin:$PATH

ADD tomcat-users.xml $CATALINA_HOME/conf/

EXPOSE 8080

CMD ["$CATALINA_HOME/bin/catalina.sh", "run"]
