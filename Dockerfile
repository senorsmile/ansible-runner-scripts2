FROM ubuntu:bionic-20200112
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
RUN apt-get update && apt-get install python3-pip zlib1g-dev curl git -y
RUN pip3 install pipenv
RUN mkdir /root/.ssh && mkdir /root/ansible
ADD ./ /root/ansible/ansible-runner-scripts2
WORKDIR root/ansible/ansible_2.9
RUN curl https://pyenv.run | bash
ENV PATH="/root/.pyenv/bin:$PATH"
RUN pipenv lock && pipenv sync
