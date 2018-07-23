#!/bin/bash
set -x -e

echo "enter install-tf-emr" > /tmp/install-tf-emr.log

# upgrade glibc to 2.19
#wget http://ftp.gnu.org/gnu/glibc/glibc-2.19.tar.gz
aws s3 cp s3://tomzeng/ml/glibc-2.19.tar.gz .
tar -xvzf glibc-2.19.tar.gz
cd glibc-2.19
mkdir -p glibc-build
cd glibc-build
#../configure --prefix='/usr'
#make
sudo make install
cd ../..
rm -rf glibc-2.19
rm glibc-2.19.tar.gz

sudo python -m pip install wheel mock numpy enum34
sudo python3 -m pip install wheel mock numpy enum34
sudo yum install -y openmpi openmpi-devel git libffi-devel
sudo sh -c 'echo "export PATH=$PATH:/usr/lib64/openmpi/bin:/usr/local/bin" >> /etc/profile'
export PATH=$PATH:/usr/lib64/openmpi/bin:/usr/local/bin
sudo ln -s /usr/lib64/openmpi/bin/mpicxx /usr/bin/
sudo ln -s /usr/lib64/openmpi/bin/orted /usr/bin/


aws s3 cp s3://tomzeng/ml/tensorflow-gpu-mkl-emr-5.14.0/tensorflow-1.8.0-cp34-cp34m-linux_x86_64/tensorflow-1.8.0-cp34-cp34m-linux_x86_64.whl /tmp/
sudo mkdir -p /usr/local/lib/python3.4/site-packages/tensorflow
sudo aws s3 cp s3://tomzeng/ml/tensorflow-gpu-mkl-emr-5.14.0/tensorflow-1.8.0-cp34-cp34m-linux_x86_64/libtensorflow.so /usr/local/lib/python3.4/site-packages/tensorflow/
sudo aws s3 cp s3://tomzeng/ml/tensorflow-gpu-mkl-emr-5.14.0/tensorflow-1.8.0-cp34-cp34m-linux_x86_64/libtensorflow_framework.so /usr/local/lib/python3.4/site-packages/tensorflow/
sudo python3 -m pip install /tmp/tensorflow-1.8.0-cp34-cp34m-linux_x86_64.whl

aws s3 cp s3://tomzeng/ml/tensorflow-gpu-mkl-emr-5.14.0/tensorflow-1.8.0-cp27-cp27m-linux_x86_64/tensorflow-1.8.0-cp27-cp27mu-linux_x86_64.whl /tmp/
sudo python -m pip install /tmp/tensorflow-1.8.0-cp27-cp27mu-linux_x86_64.whl
sudo mkdir -p /usr/local/lib/python2.7/site-packages/tensorflow
sudo aws s3 cp s3://tomzeng/ml/tensorflow-gpu-mkl-emr-5.14.0/tensorflow-1.8.0-cp27-cp27m-linux_x86_64/libtensorflow.so /usr/local/lib/python2.7/site-packages/tensorflow/
sudo aws s3 cp s3://tomzeng/ml/tensorflow-gpu-mkl-emr-5.14.0/tensorflow-1.8.0-cp27-cp27m-linux_x86_64/libtensorflow_framework.so /usr/local/lib/python2.7/site-packages/tensorflow/

# generate a rss key and add pub key to authorized_keys, copy .ssh to all nodes
#rm -f /tmp/id_rsa*
#ssh-keygen -b 2048 -t rsa -f /tmp/id_rsa -q -N ""
#aws s3 cp /tmp/id_rsa s3://tomzeng/tmp/ssh/
#aws s3 cp /tmp/id_rsa.pub s3://tomzeng/tmp/ssh/

#NOTE change the following to use your own rsa keys
aws s3 cp s3://tomzeng/tmp/ssh/id_rsa.pub /home/hadoop/.ssh/
aws s3 cp s3://tomzeng/tmp/ssh/id_rsa /home/hadoop/.ssh/
cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys
chmod 600 /home/hadoop/.ssh/id_rsa

echo "Host *" >> /home/hadoop/.ssh/config
echo "   StrictHostKeyChecking no" >> /home/hadoop/.ssh/config
echo "   UserKnownHostsFile=/dev/null" >> /home/hadoop/.ssh/config
chmod 600 /home/hadoop/.ssh/config

aws s3 cp s3://tomzeng/ml/nvidia/nccl_2.1.15-1+cuda9.1_x86_64.txz .
tar xvf nccl_2.1.15-1+cuda9.1_x86_64.txz
sudo mv nccl_2.1.15-1+cuda9.1_x86_64 /usr/local/lib/nccl_2.1.15

export LD_LIBRARY_PATH=/usr/local/lib/nccl_2.1.15/lib
sudo sh -c 'echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/nccl_2.1.15/lib" >> /etc/profile'

cd /home/hadoop
git clone https://github.com/uber/horovod.git
git clone https://github.com/alsrgv/benchmarks
cd benchmarks
git checkout horovod_v2
cd

wait_for_nvidia() {
  echo "enter wait_fornvidia" >> /tmp/install-tf-emr.log
  while [ ! -f /mnt/nvidia/cuda-9.1/include/cuda_runtime.h ]
  do
    sleep 60
  done
  echo "exited wait_fornvidia" >> /tmp/install-tf-emr.log
}

install_horovod() {
  echo "enter install_horovod" >> /tmp/install-tf-emr.log
  wait_for_nvidia
  sudo HOROVOD_GPU_ALLREDUCE=NCCL HOROVOD_NCCL_HOME=/usr/local/lib/nccl_2.1.15 PATH=$PATH:/usr/lib64/openmpi/bin python3 -m pip install horovod==0.13.7 -U &>> /tmp/install-tf-emr.log
  sudo HOROVOD_GPU_ALLREDUCE=NCCL HOROVOD_NCCL_HOME=/usr/local/lib/nccl_2.1.15 PATH=$PATH:/usr/lib64/openmpi/bin python27 -m pip install horovod==0.13.7 -U &>> /tmp/install-tf-emr.log
  echo "exited install_horovod" >> /tmp/install-tf-emr.log
}

install_horovod &
echo "exited install-tf-horovod-emr" >> /tmp/install-tf-emr.log

