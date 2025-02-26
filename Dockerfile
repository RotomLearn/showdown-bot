FROM rust:1.81-slim AS build

RUN apt update && apt install -y python3.11 make build-essential python3.11-venv git wget unzip zip

# Create directory for libtorch
WORKDIR /opt

# Download and extract libtorch v2.6.0
RUN wget https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.6.0%2Bcpu.zip \
    && unzip libtorch-cxx11-abi-shared-with-deps-2.6.0+cpu.zip \
    && rm libtorch-cxx11-abi-shared-with-deps-2.6.0+cpu.zip

# Set environment variables
ENV LIBTORCH=/opt/libtorch
ENV LD_LIBRARY_PATH=${LIBTORCH}/lib

WORKDIR /

RUN git clone https://github.com/RotomLearn/poke-engine.git
RUN cd poke-engine/poke-engine-py && cargo build --release --features poke-engine/gen9,poke-engine/terastallization --no-default-features


COPY requirements.txt requirements.txt

RUN mkdir ./packages && \
    python3 -m venv venv && \
    . venv/bin/activate && \
    # pip24 is required for --config-settings
    pip install --upgrade pip==24.2 && \
    pip uninstall -y poke-engine && pip install -v --force-reinstall \
    --no-cache-dir ../poke-engine/poke-engine-py \
    --config-settings="build-args=--features poke-engine/gen9,poke-engine/terastallization --no-default-features" && \
    pip install -v --target ./packages -r requirements.txt

FROM python:3.11-slim

WORKDIR /foul-play

COPY config.py /foul-play/config.py
COPY constants.py /foul-play/constants.py
COPY data /foul-play/data
COPY run.py /foul-play/run.py
COPY fp /foul-play/fp
COPY teams /foul-play/teams

COPY --from=build /packages/ /usr/local/lib/python3.11/site-packages/

ENV PYTHONIOENCODING=utf-8

CMD ["python3", "run.py"]