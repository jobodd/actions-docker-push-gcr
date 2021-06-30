FROM gcr.io/google.com/cloudsdktool/cloud-sdk:347.0.0-slim
RUN apt update && \
    apt upgrade && \
    apt install -y git bash
RUN apt-get install kubectl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
