# Mate Rating Tracker

A web application that tracks and displays mate ratings. The application automatically updates rankings daily and provides a visual representation of the current standings.

## Features

- Automatic daily rating updates
- Real-time ranking visualization
- Web interface for easy access
- Automatic data collection and processing

## Requirements

- Julia 1.6 or higher
- Required Julia packages (specified in Project.toml)

## Setup

1. Clone the repository
2. Install Julia packages:
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

3. Run the web server:
```julia
julia web_server.jl
```

## License

MIT
