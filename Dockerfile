# VERSION 2.2.2
# DESCRIPTION: Basic Airflow container
# BUILD: docker build --rm -t puckel/docker-airflow .

FROM python:3.8.13-slim-buster


# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=2.2.2
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG KRB_CONFIG=/etc
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

# Spark
ARG SPARK_VERSION="2.3.0"
ARG HADOOP_VERSION="2.7"

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
        python3-dev \
        unixodbc-dev \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install apache-airflow[crypto,celery,postgres,oracle,hive,jdbc,mysql,ssh,gcp,password${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install -U celery[redis] \
    && pip install psycopg2==2.8.6 \
    && pip install psycopg2-binary==2.8.6 \
    && pip install SQLAlchemy==1.3.18 \
    && pip install flask-bcrypt \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base \
    && apt-get update \
    && apt-get install -y wget \
    && apt-get install -y gnupg2 \
    && apt-get install -y python-pip libkrb5-dev \
    && apt-get install -y apt-transport-https ca-certificates
#    \ && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
#    && curl -sSL https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list \
#    && apt-get update \
#    && ACCEPT_EULA=Y apt-get install -y msodbcsql17

COPY script/entrypoint.sh /entrypoint.sh
COPY config/airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg

# copy file krb5.conf
COPY script/krb5.conf ${KRB_CONFIG}/krb5.conf

# config hostname worker
#COPY script/hostname_resolver.py ${AIRFLOW_USER_HOME}/hostname_resolver.py
#RUN cp ${AIRFLOW_USER_HOME}/hostname_resolver.py $(pip show apache-airflow | grep ^Location | cut -d' ' -f2)/airflow/

RUN mkdir -p /usr/share/man/man1/

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    apt-get install -y gnupg2 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EB9B1D8886F44E2A && \
    add-apt-repository "deb http://security.debian.org/debian-security stretch/updates main" && \
    apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    pip freeze && \
    java -version $$ \
    javac -version

# Setup JAVA_HOME
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
RUN export JAVA_HOME


# install all requirements
COPY script/requirements.txt /requirements.txt
RUN pip install -r requirements.txt

## SPARK files and variables
#ENV SPARK_HOME /usr/local/spark
#
## Spark submit binaries and jars (Spark binaries must be the same version of spark cluster)
#COPY script/spark-2.3.0-bin-hadoop2.7 /tmp/spark-2.3.0-bin-hadoop2.7
#RUN cd "/tmp" && \
##    wget --no-verbose "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
##    tar -xvzf "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" && \
#    mkdir -p "${SPARK_HOME}/bin" && \
#    mkdir -p "${SPARK_HOME}/assembly/target/scala-2.12/jars" && \
#    cp -a "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}/bin/." "${SPARK_HOME}/bin/" && \
#    cp -a "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}/jars/." "${SPARK_HOME}/assembly/target/scala-2.12/jars/"
##    && \ rm "spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"
#
## Create SPARK_HOME env var
#RUN export SPARK_HOME
#ENV PATH $PATH:/usr/local/spark/bin
#
## COPY FILE HADOOP_CONF
#COPY script/hadoop-conf ${SPARK_HOME}/conf/hadoop-conf
#COPY script/spark-defaults.conf ${SPARK_HOME}/conf/spark-defaults.conf

# install oracle client
RUN mkdir -p /opt/oracle
COPY script/instantclient_21_1 /opt/oracle/instantclient_21_1

RUN apt-get install libaio1

ENV LD_LIBRARY_PATH /opt/oracle/instantclient_21_1
RUN export LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/opt/oracle/instantclient_21_1


RUN chown -R airflow: ${AIRFLOW_USER_HOME}
RUN chown -R airflow: ${KRB_CONFIG}/krb5.conf
# RUN chown -R airflow: /entrypoint.sh
RUN chmod +x entrypoint.sh
#RUN chown -R airflow: ${SPARK_HOME}/


EXPOSE 8080 5555 8793 5432 6379

USER airflow
WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"]