FROM rust:1.81-slim AS build

# Install build dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip \
    git \
    make \
    build-essential \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Download and extract libtorch
WORKDIR /opt
RUN wget https://download.pytorch.org/libtorch/cpu/libtorch-cxx11-abi-shared-with-deps-2.6.0%2Bcpu.zip \
    && unzip "libtorch-cxx11-abi-shared-with-deps-2.6.0+cpu.zip" \
    && rm "libtorch-cxx11-abi-shared-with-deps-2.6.0+cpu.zip"

# Set environment variables for Rust build
ENV LIBTORCH=/opt/libtorch
ENV LD_LIBRARY_PATH=${LIBTORCH}/lib

# Clone and build poke-engine
WORKDIR /app
RUN git clone https://github.com/RotomLearn/poke-engine.git
WORKDIR /app/poke-engine/poke-engine-py
RUN cargo build --release --features poke-engine/gen9,poke-engine/terastallization --no-default-features

# Install the package using pip after cargo build
RUN pip install --break-system-packages -e .

# Create a Python script to copy the module files
RUN echo 'import os\n\
import shutil\n\
import poke_engine\n\
\n\
module_dir = os.path.dirname(poke_engine.__file__)\n\
print(f"Module directory: {module_dir}")\n\
\n\
dest_dir = "/app/module_copy/poke_engine"\n\
os.makedirs(dest_dir, exist_ok=True)\n\
\n\
# Copy all files from the module directory\n\
for root, dirs, files in os.walk(module_dir):\n\
    for file in files:\n\
        src_path = os.path.join(root, file)\n\
        rel_path = os.path.relpath(src_path, start=module_dir)\n\
        dst_path = os.path.join(dest_dir, rel_path)\n\
        os.makedirs(os.path.dirname(dst_path), exist_ok=True)\n\
        shutil.copy2(src_path, dst_path)\n\
\n\
print("Module copying complete")' > /app/copy_module.py

# Run the Python script
RUN python3 /app/copy_module.py

FROM python:3.11-slim

# Install libgomp (OpenMP runtime library) for the poke_engine module
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy libtorch
COPY --from=build /opt/libtorch /opt/libtorch
ENV LIBTORCH=/opt/libtorch
ENV LD_LIBRARY_PATH=${LIBTORCH}/lib

# Copy the module directory from build stage
COPY --from=build /app/module_copy/poke_engine/ /usr/local/lib/python3.11/site-packages/poke_engine/

# Copy application files
WORKDIR /foul-play
COPY config.py /foul-play/config.py
COPY constants.py /foul-play/constants.py
COPY data /foul-play/data
COPY run.py /foul-play/run.py
COPY fp /foul-play/fp
COPY teams /foul-play/teams
COPY requirements.txt /foul-play/requirements.txt
COPY poke_engine_config.json /foul-play/poke_engine_config.json

# Install Python dependencies
RUN pip install --break-system-packages -r requirements.txt

ENV PYTHONIOENCODING=utf-8
# CMD ["/bin/bash", "-c", "echo 'Container running'; sleep infinity"]
CMD ["python3", "run.py"]