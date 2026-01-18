# 🤖 FRC Visualizer

**High-performance, next-generation visualization for FIRST Robotics Competition data.**

[![Build and Export](https://github.com/reecelikesramen/frc-visualization/actions/workflows/build.yml/badge.svg)](https://github.com/reecelikesramen/frc-visualization/actions/workflows/build.yml)
[![Godot](https://img.shields.io/badge/Godot-4.3+-478CBF?logo=godot-engine&logoColor=white)](https://godotengine.org)
[![Rust](https://img.shields.io/badge/Rust-2024-000000?logo=rust&logoColor=white)](https://www.rust-lang.org)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

FRC Visualizer is built from the ground up to provide a smooth, low-latency interface for monitoring and analyzing robot data. By leveraging a **Godot 4** frontend and a **Rust-powered GDExtension** backend, it achieves unmatched performance and memory efficiency.

<p align="center">
  ![3D Field View](/images/demo1.mp4)
  <br>
  <em><strong>3D Field View:</strong> Shows game pieces, robot pose, swerve states, and the full UI.</em>
</p>

---

## ✨ Features

- 🏎️ **Extreme Performance**: Data layer implemented in Rust with a columnar ring buffer for zero-allocation history tracking.
- 🕒 **Time Travel**: Scrub through recorded session data with a high-fidelity timeline, zoom support, and live-tracking sticky-scroll.
- 📊 **Dual Views**: Seamlessly switch between **2D Field** and **3D Field** visualizations.
- 🛠️ **Live Tuning**: Dedicated tuning topics supporting AdvantageKit's LoggedTuning paradigm.
- 🌐 **NT4 Support**: Full support for NetworkTables 4, including structured data, arrays, and schema-based decoding.
- 🚀 **Multithreaded Networking**: Dedicated background thread for NT4 synchronization using `tokio` and `nt_client`.

---

<p align="center">
  ![2D Field View](/images/demo2.mp4)
  <br>
  <em><strong>2D Field View:</strong> Shows game pieces, robot pose, and swerve states in a top-down view.</em>
</p>

---

## 🛠️ Tech Stack

- **Frontend**: [Godot 4.3+](https://godotengine.org/) (Forward+ Renderer)
- **Backend (GDExtension)**: [Rust](https://www.rust-lang.org/) via [`godot-rust`](https://godot-rust.github.io/)
- **Networking**: [`nt_client`](https://github.com/DatAsianBoi123/nt_client) (Pure Rust NT4 implementation)
- **Concurrency**: [`tokio`](https://tokio.rs/) for async I/O.

---

## 🚀 Getting Started

### Prerequisites

- [Rust](https://www.rust-lang.org/tools/install) (latest stable or 2024 edition)
- [Godot Engine 4.3+](https://godotengine.org/download)

### Local Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/reecelikesramen/frc-visualization.git
   cd frc-visualization
   ```

2. **Build the Rust GDExtension:**
   ```bash
   cd nt4_logging
   cargo build
   ```
   *Note: This will generate the shared library for your OS and place it in `godot/bin/` where Godot expects it.*

3. **Open the project in Godot:**
   - Launch Godot 4.3+.
   - Import the project from the `godot/` directory.
   - Press **F5** (or the Play button) to run the visualizer.

---

## 🗺️ Roadmap

- [x] Real-time & Recorded NT4 data visualization
- [x] Timeline scrubbing & history replay
- [x] High-performance 2D/3D field views
- [x] Structured data (structs) support
- [x] Automatic UI state persistence
- [ ] **Custom Robot Models**: Load your team's specific GLB/OBJ models.
- [ ] **Plugin System**: Build custom visualizers and views.
- [ ] **Log File Support**: Direct reading and exporting of standard robot log formats.
- [ ] **Command Hierarchy**: Visualize the active robot command tree.

---

## 🤝 Credits

- [**nt_client**](https://github.com/DatAsianBoi123/nt_client) - High-performance NT4 client library.
- [**AdvantageScope**](https://github.com/Mechanical-Advantage/AdvantageScope) - The inspiration for this modern take on FRC visualization.

---

## 📄 License

This project is licensed under the Apache-2.0 License - see the [LICENSE](LICENSE) file for details.
