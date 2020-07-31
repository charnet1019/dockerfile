From jenkinsci/blueocean:1.22.0
 
USER root
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
        && apk update \
        && apk add --no-cache sudo gettext ansible \
        && echo "jenkins ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
USER jenkins
