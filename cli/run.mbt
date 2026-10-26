///|
fn policy(config : Config) -> @liberty.RangePolicy {
  match config.options.get("--policy") {
    Some("clamp") => Clamp
    Some("extrapolate") => Extrapolate
    _ => Reject
  }
}

///|
async fn print_result(config : Config, json : Json, text : String) -> Unit {
  @stdio.stdout.write(
    if config.flags.contains("--json") {
      json.stringify(indent=2) + "\n"
    } else {
      text
    },
  )
}

///|
pub async fn run(request : Request) -> Int {
  match request {
    Help(command) => {
      @stdio.stdout.write(help(command))
      0
    }
    Version => {
      @stdio.stdout.write("moon-liberty 0.4.0\n")
      0
    }
    Run(config) => {
      if config.command == "compat" || config.command == "expand" {
        return standard_command(config)
      }
      if config.command == "truth" {
        let expression = @liberty.parse_logic(config.inputs[0])
        let maximum = match config.options.get("--max-inputs") {
          Some(value) => positive_integer(value, 16)
          None => 12
        }
        let rows = @liberty.truth_table(expression, max_inputs=maximum)
        let json : Json = {
          "schema": "moonliberty.truth.v1",
          "signals": @liberty.logic_signals(expression).to_json(),
          "rows": rows
          .map(row => {
            (
              {
                "inputs": row.inputs
                .map(pair => {
                  (
                    { "name": pair.0.to_json(), "value": pair.1.to_json() } :
                    Json)
                })
                .to_json(),
                "output": row.output.to_json(),
              } : Json)
          })
          .to_json(),
        }
        print_result(config, json, json.stringify(indent=2) + "\n")
        return 0
      }
      let library = load_file(config.inputs[0])
      match config.command {
        "inspect" => {
          let inventory = library.inventory()
          print_result(
            config,
            @liberty.inventory_json(library),
            "Library: " +
            library.name +
            "\nCells: \{inventory.cells}\nPins: \{inventory.pins}\nArcs: \{inventory.arcs}\nTables: \{inventory.tables}\nModel errors: \{inventory.errors}\nModel warnings: \{inventory.warnings}\n",
          )
          0
        }
        "lint" => {
          let findings = @liberty.lint_library(library)
          let errors = findings.filter(f => f.severity is Error).length()
          let warnings = findings.length() - errors
          let out = StringBuilder()
          out.write_string("Errors: \{errors}; warnings: \{warnings}\n")
          for issue in findings {
            out.write_string(
              "\{issue.code} at \{issue.position.line}:\{issue.position.column} " +
              issue.path +
              ": " +
              issue.message +
              "\n",
            )
          }
          print_result(config, @liberty.lint_json(library), out.to_string())
          if errors == 0 {
            0
          } else {
            1
          }
        }
        "query" => {
          let options = config.options
          let query = @liberty.query_timing(
            library,
            options["--cell"],
            options["--pin"],
            options["--related"],
            options["--table"],
            @liberty.finite_number(options["--slew"]),
            @liberty.finite_number(options["--load"]),
            condition?=options.get("--when"),
            policy=policy(config),
          )
          print_result(
            config,
            @liberty.query_json(query),
            "Seconds: \{query.seconds}\nValue in library time unit: \{query.raw_value}\nClamped: \{query.clamped}\nExtrapolated: \{query.extrapolated}\n",
          )
          0
        }
        "diff" => {
          let other = load_file(config.inputs[1])
          let maximum = match config.options.get("--max-changes") {
            Some(value) => positive_integer(value, 100000)
            None => 10000
          }
          let comparison = @liberty.compare_libraries(
            library,
            other,
            max_changes=maximum,
          )
          let out = StringBuilder()
          out.write_string(
            "Changes: \{comparison.total_changes}; truncated: \{comparison.truncated}\n",
          )
          for change in comparison.changes {
            out.write_string(change.path + "\n")
          }
          print_result(
            config,
            @liberty.comparison_json(comparison),
            out.to_string(),
          )
          if comparison.total_changes == 0 {
            0
          } else {
            1
          }
        }
        _ => {
          let selected = if config.command == "extract" {
            let names = config.options["--cells"]
              .split(",")
              .map(name => name.trim().to_owned())
              .to_array()
            @liberty.select_cells(library, names)
          } else {
            library.source
          }
          let text = @liberty.write_liberty(selected)
          let output = config.options["--output"]
          write_text(output, text, config.flags.contains("--force"))
          print_result(
            config,
            { "status": "written", "output": output.to_json() },
            "Wrote " + output + "\n",
          )
          0
        }
      }
    }
  }
}

///|
async fn source_map(config : Config) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  if config.options.get("--sources") is Some(path) {
    let text = read_text(path)
    let json = @json.parse(text) catch {
      _ => raise usage("source map must be valid JSON: " + path)
    }
    guard json is Object(entries) else {
      raise usage("source map must be a JSON object")
    }
    for name, value in entries {
      guard value is String(body) else {
        raise usage("source map values must be source text strings: " + name)
      }
      result[name] = body
    }
  }
  result
}

///|
async fn standard_command(config : Config) -> Int {
  let standard = @liberty.parse_standard(config.options["--standard"])
  let text = read_text(config.inputs[0])
  let sources = source_map(config)
  let root = @liberty.parse_liberty_sources(text, sources) catch {
    @liberty.LibertyError(code, message, position) =>
      raise @liberty.LibertyError(
        code,
        config.inputs[0] + ": " + message,
        position,
      )
  }
  if config.command == "compat" {
    let report = @liberty.compatibility_report(root, standard~)
    let errors = report.findings.filter(f => f.severity is Error).length()
    let json = @liberty.compatibility_json(report)
    print_result(config, json, json.stringify(indent=2) + "\n")
    if errors == 0 {
      0
    } else {
      1
    }
  } else {
    let output = config.options["--output"]
    write_text(
      output,
      @liberty.write_liberty(root),
      config.flags.contains("--force"),
    )
    print_result(
      config,
      {
        "status": "expanded",
        "output": output.to_json(),
        "target_standard": standard.label().to_json(),
        "complete_standard_conformance": false,
      },
      "Wrote expanded library: " + output + "\n",
    )
    0
  }
}
