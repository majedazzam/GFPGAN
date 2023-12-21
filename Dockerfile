FROM nvidia/cuda:11.1.1-runtime-ubuntu18.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    # OpenCV deps
    libglib2.0-0 libsm6 libxext6 libxrender1 libgl1-mesa-glx \
    # c++
    g++ \
    # others
    wget unzip
WORKDIR /app
ENV PATH="/root/miniconda3/bin:/root/.local/bin:${PATH}"
ENV PYTHONPATH="/app"

# Install Miniconda
ENV CONDA_AUTO_UPDATE_CONDA=false
ENV PATH=/opt/conda/bin:$PATH

# Install wget and other necessary tools (if not already present)
RUN apt-get update && apt-get install -y wget

# Download Miniconda installer
RUN wget -O ~/miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-py38_4.10.3-Linux-x86_64.sh

# Install Miniconda
RUN chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

# Configure Conda
RUN /opt/conda/bin/conda clean -ya && \
    conda update -n base -c defaults conda && \
    /opt/conda/bin/conda clean -ya

RUN conda config --add channels conda-forge && \
    conda install conda-build

RUN conda build purge && \
    conda init

# Ninja
RUN wget https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip && \
    unzip ninja-linux.zip -d /usr/local/bin/ && \
    update-alternatives --install /usr/bin/ninja ninja /usr/local/bin/ninja 1 --force

# basicsr facexlib
RUN pip install -U pip && \
    pip install torch==1.8.2+cu111 torchvision==0.9.2+cu111 -f https://download.pytorch.org/whl/lts/1.8/torch_lts.html

RUN pip install opencv-python basicsr facexlib realesrgan boto3 python-json-logger uuid

# weights
RUN wget https://github.com/TencentARC/GFPGAN/releases/download/v0.2.0/GFPGANCleanv1-NoCE-C2.pth \
        -P experiments/pretrained_models &&\
    wget https://github.com/TencentARC/GFPGAN/releases/download/v0.1.0/GFPGANv1.pth \
        -P experiments/pretrained_models && \
    wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.3.pth \
        -P experiments/pretrained_models && \
    wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.4.pth \
        -P experiments/pretrained_models && \
    wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/RestoreFormer.pth \
        -P experiments/pretrained_models && \
    wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/CodeFormer.pth \
        -P gfpgan/weights && \
    wget https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth \
        -P /usr/local/lib/python3.6/dist-packages/realesrgan/weights/ && \
    wget https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth \
        -P /usr/local/lib/python3.6/dist-packages/weights/ && \
    wget https://github.com/xinntao/facexlib/releases/download/v0.1.0/detection_Resnet50_Final.pth \
        -P gfpgan/weights && \
    wget https://github.com/xinntao/facexlib/releases/download/v0.2.2/parsing_parsenet.pth \
        -P gfpgan/weights

RUN rm -rf /var/cache/apt/* /var/lib/apt/lists/* && \
    apt-get autoremove -y && apt-get clean

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .
RUN pip3 install .

CMD ["python3", "inference_gfpgan.py"]
