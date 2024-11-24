FROM julia:1.11

WORKDIR /app
COPY . .

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Julia packages
RUN julia -e 'using Pkg; \
    Pkg.activate("."); \
    Pkg.add(["HTTP"]); \
    Pkg.instantiate(); \
    Pkg.precompile()'

# Set environment variables
ENV JULIA_DEBUG=all
ENV PORT=10000

EXPOSE 10000

# アプリケーションを実行
CMD ["julia", "--project=.", "web_server.jl"]
