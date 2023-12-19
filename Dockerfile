RUN wget https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-lin
    unzip ninja-linux.zip -d /usr/local/bin/ && \
    update-alternatives --install /usr/bin/ninja ninja /usr/local/bin/ninja 1 --force


# basicsr facexlib
RUN python3 -m pip install --upgrade pip && \
    pip3 install --no-cache-dir basicsr

RUN pip3 install --no-cache-dir facexlib

COPY requirements.txt .
    pip3 install --no-cache-dir torch>=1.7 opencv-python>=4.5 && \
    pip3 install --no-cache-dir basicsr facexlib

RUN pip3 install --no-cache-dir -r requirements.txt

RUN wget https://github.com/TencentARC/GFPGAN/releases/download/v0.1.0/GFPGANv1.pth \
# weights
RUN wget https://github.com/TencentARC/GFPGAN/releases/download/v0.2.0/GFPGANCleanv1-NoCE-C2.pth \
        -P experiments/pretrained_models &&\
    wget https://github.com/TencentARC/GFPGAN/releases/download/v0.1.0/GFPGANv1.pth \
        -P experiments/pretrained_models

RUN rm -rf /var/cache/apt/* /var/lib/apt/lists/* && \
    apt-get autoremove -y && apt-get clean

RUN python3 setup.py develop
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .
RUN python3 setup.py develop && \
    pip3 install realesrgan

CMD ["python3", "inference_gfpgan_full.py", "--model_path", "experiments/pretrained_models/GFPGANv1.pth", \
     "--test_path", "inputs/whole_imgs"]
CMD ["python3", "inference_gfpgan.py", "--upscale", "2", "--test_path", "inputs/whole_imgs", "--save_root", "results"]
