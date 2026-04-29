# check_dir_file_age.sh
<p align="center">
<img src="https://img.shields.io/badge/License-MIT-blueviolet?style=for-the-badge" alt="License: MIT">
<img src="https://img.shields.io/badge/Built%20by-NEMESTER-DARKGREEN?style=for-the-badge" alt="Built by Nemester"></a>
</p>

Nagios / Icinga plugin to monitor the age of the newest or oldest file in a directory.
> **Note:** This plugin is distinct from the standard `check_file_age` plugin shipped with monitoring-plugins, which checks a single specific file by path. `check_dir_file_age.sh` scans an entire directory and selects either the newest or oldest file automatically.

---

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Parameters](#parameters)
- [Modes](#modes)
- [Threshold Semantics](#threshold-semantics)
- [Example Usage](#example-usage)
- [Example Output](#example-output)
  - [Without perfdata (default)](#without-perfdata-default)
  - [With perfdata](#with-perfdata)
  - [Warning](#warning)
  - [Critical](#critical)
- [Return Codes](#return-codes)
- [NRPE Integration](#nrpe-integration)
- [Notes](#notes)
- [License](#license)

---

## Description

`check_dir_file_age.sh` checks (recursive) the newest or oldest file in a given directory and evaluates its age against warning and critical thresholds.
If the age of the file is above the threshold, a corresponding alarm is triggered.

This is useful for monitoring:
- backups
- log generation
- file drops / ETL pipelines
- export jobs
- retention / cleanup jobs


---

## Requirements

- Linux system with:
  - `bash`
  - `find`
  - `sort`
  - `awk`
  - `date`
  - `stat`
- Nagios / Icinga (or compatible monitoring system)

---

## Installation

1. Copy script to plugin directory:
```
/usr/lib/nagios/plugins/check_dir_file_age.sh
```

2. Set executable permissions:
```
chmod 755 /usr/lib/nagios/plugins/check_dir_file_age.sh
```

---

## Usage

```
check_dir_file_age.sh --directory <path> --warn <hours> --crit <hours> [--mode newest|oldest] [--perfdata]
```

### Parameters

| Parameter     | Description                                                                  |
|---------------|------------------------------------------------------------------------------|
| `--directory` | Directory to check                                                           |
| `--warn`      | Warning threshold (hours)                                                    |
| `--crit`      | Critical threshold (hours)                                                   |
| `--mode`      | `newest` or `oldest`, which file to evaluate (optional, default: `newest`)  |
| `--perfdata`  | Enable perfdata output (optional)                                            |

---

## Modes

| Mode     | Selects                       | Typical use case                                                          |
|----------|-------------------------------|---------------------------------------------------------------------------|
| `newest` | Most recently modified file   | Detect stalled writes, e.g. a backup job stopped producing files         |
| `oldest` | Least recently modified file  | Detect missing cleanup, e.g. old files not being rotated or archived     |

---

## Threshold Semantics

| Metric   | Behavior        |
|----------|----------------|
| File age | higher is worse |

Example:
```
--warn 24 --crit 48
```
- ≥ 24h → WARNING  
- ≥ 48h → CRITICAL  

---

## Example Usage

```
check_dir_file_age.sh --directory /backup --warn 24 --crit 48
```
```
check_dir_file_age.sh --directory /data/export --warn 2 --crit 4 --perfdata
```
```
check_dir_file_age.sh --directory /data/archive --warn 72 --crit 168 --mode oldest
```
```
check_dir_file_age.sh --directory /data/archive --warn 72 --crit 168 --mode oldest --perfdata
```

---

## Example Output

### Without perfdata (default)

```
[OK]: newest file "backup.sql" is 2 hours old in /backup
```

### With perfdata

```
[OK]: newest file "backup.sql" is 2 hours old in /backup | file_age_hours=2;24;48;0;
```

### Warning

```
[WARNING]: newest file "backup.sql" is 26 hours old in /backup
```
```
[WARNING]: oldest file "import_2024-01-01.csv" is 80 hours old in /data/archive
```

### Critical

```
[CRITICAL]: newest file "backup.sql" is 52 hours old in /backup
```
```
[CRITICAL]: oldest file "import_2024-01-01.csv" is 175 hours old in /data/archive
```

---

## Return Codes

| Code | State    |
|------|----------|
| 0    | OK       |
| 1    | WARNING  |
| 2    | CRITICAL |
| 3    | UNKNOWN  |

---

## NRPE Integration

Example `/etc/nagios/nrpe.cfg`:

```
command[check_newest_file]=/usr/lib/nagios/plugins/check_dir_file_age.sh --directory /backup --warn 24 --crit 48
command[check_oldest_file]=/usr/lib/nagios/plugins/check_dir_file_age.sh --directory /data/archive --warn 72 --crit 168 --mode oldest
```

With perfdata:

```
command[check_newest_file_pd]=/usr/lib/nagios/plugins/check_dir_file_age.sh --directory /backup --warn 24 --crit 48 --perfdata
command[check_oldest_file_pd]=/usr/lib/nagios/plugins/check_dir_file_age.sh --directory /data/archive --warn 72 --crit 168 --mode oldest --perfdata
```

(Restart NRPE)

---

## Notes

- Only regular files are considered (no directories)
- The target file is determined by modification time
- Works with filenames containing spaces
- If no files are found, the check returns CRITICAL
- Mode defaults to `newest` 
- Perfdata is disabled by default and must be explicitly enabled (flag: `--perfdata`)

---

## License

MIT License
