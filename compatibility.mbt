///|
/// A declared interpretation target, never automatic version detection.
pub(all) enum StandardEdition {
  Liberty2017_06
} derive(Eq, Debug)

///|
pub fn StandardEdition::label(self : StandardEdition) -> String {
  match self {
    Liberty2017_06 => "Liberty 2017.06"
  }
}

///|
pub fn parse_standard(text : String) -> StandardEdition raise LibertyError {
  match text {
    "2017.06" | "liberty-2017.06" => Liberty2017_06
    _ =>
      raise failure(
        "UnsupportedStandard",
        "supported target: Liberty 2017.06",
        no_position(),
      )
  }
}

///|
pub(all) struct FormatFeature {
  family : String
  occurrences : Int32
  evaluation : String
} derive(Eq, Debug)

///|
pub(all) struct CompatibilityReport {
  standard : StandardEdition
  library : String
  findings : Array[Finding]
  features : Array[FormatFeature]
  roundtrip_verified : Bool
  complete_conformance : Bool
} derive(Debug)

///|
fn declaration_argument(
  arguments : Array[Array[Atom]],
  index : Int32,
) -> String? {
  if index >= arguments.length() {
    return None
  }
  match arguments[index] {
    [atom] => Some(atom_text(atom))
    _ => None
  }
}

///|
fn collect_declarations(
  root : Group,
  attrs : Map[String, Map[String, String]],
  groups : Map[String, String],
  findings : Array[Finding],
) -> Unit {
  for item in root.items {
    match item {
      Complex("define", args, pos) => {
        let name = declaration_argument(args, 0).unwrap_or("")
        let parent = declaration_argument(args, 1).unwrap_or("")
        let value_type = declaration_argument(args, 2).unwrap_or("")
        if args.length() != 3 ||
          name.is_empty() ||
          parent.is_empty() ||
          !["boolean", "string", "integer", "float"].contains(value_type) {
          add_finding(
            findings, "InvalidDefine", "/library/define", "define needs name, group and boolean/string/integer/float type",
            pos,
          )
        } else {
          let parents = attrs.get(name).unwrap_or(Map([]))
          if parents.contains(parent) {
            add_finding(
              findings,
              "DuplicateDefine",
              "/library/define/" + name,
              "attribute definition repeated",
              pos,
            )
          } else {
            parents[parent] = value_type
            attrs[name] = parents
          }
        }
      }
      Complex("define_group", args, pos) => {
        let name = declaration_argument(args, 0).unwrap_or("")
        let parent = declaration_argument(args, 1).unwrap_or("")
        if args.length() != 2 || name.is_empty() || parent.is_empty() {
          add_finding(
            findings, "InvalidDefineGroup", "/library/define_group", "define_group needs group and parent",
            pos,
          )
        } else if groups.contains(name) {
          add_finding(
            findings,
            "DuplicateDefineGroup",
            "/library/define_group/" + name,
            "group definition repeated",
            pos,
          )
        } else {
          groups[name] = parent
        }
      }
      _ => ()
    }
  }
}

///|
fn attribute_value_valid(value_type : String, atoms : Array[Atom]) -> Bool {
  guard atoms is [atom] else { return false }
  let text = atom_text(atom)
  match value_type {
    "string" => atom is Text(_)
    "boolean" => text == "true" || text == "false"
    "integer" => {
      let start = if text.has_prefix("+") || text.has_prefix("-") {
        1
      } else {
        0
      }
      if text.length() == start {
        return false
      }
      for i = start; i < text.length(); i = i + 1 {
        if text[i] < 48 || text[i] > 57 {
          return false
        }
      }
      true
    }
    "float" => {
      ignore(finite_number(text)) catch {
        _ => return false
      }
      true
    }
    _ => false
  }
}

///|
/// Recognition here is for coverage reporting, not a complete 2017.06 schema.
fn feature_family(kind : String) -> (String, String) {
  if ["bus", "bundle", "type"].contains(kind) {
    ("bus_bundle", "preserved_only")
  } else if ["ff", "ff_bank", "latch", "latch_bank", "statetable"].contains(
      kind,
    ) {
    ("sequential", "preserved_only")
  } else if kind.has_prefix("ocv_") {
    ("variation_lvf", "preserved_only")
  } else if kind.has_prefix("output_current") ||
    kind.has_prefix("ccs_") ||
    [
      "vector", "receiver_capacitance", "receiver_capacitance1_rise", "receiver_capacitance1_fall",
    ].contains(kind) {
    ("current_waveform", "preserved_only")
  } else if [
      "internal_power", "leakage_power", "rise_power", "fall_power", "power_lut_template",
    ].contains(kind) {
    ("power", "preserved_only")
  } else if ["cell_rise", "cell_fall", "rise_transition", "fall_transition"].contains(
      kind,
    ) {
    ("nldm_combinational", "eligible_after_query_checks")
  } else if ["rise_constraint", "fall_constraint"].contains(kind) {
    ("nldm_constraint", "table_lookup_only")
  } else if [
      "library", "cell", "pin", "pg_pin", "timing", "lu_table_template", "operating_conditions",
      "wire_load", "wire_load_selection", "scaled_cell", "input_voltage", "output_voltage",
    ].contains(kind) {
    ("library_structure", "model_specific")
  } else {
    ("unclassified_extension", "preserved_only")
  }
}

///|
fn inspect_format(
  group : Group,
  parent : String,
  path : String,
  attrs : Map[String, Map[String, String]],
  groups : Map[String, String],
  counts : Map[String, Int32],
  modes : Map[String, String],
  findings : Array[Finding],
) -> Unit {
  let (family, mode) = feature_family(group.kind)
  counts[family] = counts.get(family).unwrap_or(0) + 1
  modes[family] = mode
  if family == "unclassified_extension" {
    let defined = groups.contains(group.kind)
    if !defined {
      add_finding(
        findings,
        "UnclassifiedGroup",
        path,
        "group retained; no complete standard/schema classification is claimed",
        group.position,
        severity=Warning,
      )
    }
  }
  if groups.get(group.kind) is Some(declared_parent) &&
    declared_parent != parent {
    add_finding(
      findings,
      "DefinedGroupParent",
      path,
      "declared parent is " + declared_parent,
      group.position,
    )
  }
  for item in group.items {
    match item {
      Section(child) =>
        inspect_format(
          child,
          group.kind,
          path + "/" + child.kind + "(" + child.name() + ")",
          attrs,
          groups,
          counts,
          modes,
          findings,
        )
      Attribute(name, atoms, pos) =>
        if attrs.get(name) is Some(parents) {
          match parents.get(group.kind) {
            Some(value_type) =>
              if !attribute_value_valid(value_type, atoms) {
                add_finding(
                  findings,
                  "DefinedAttributeType",
                  path + "/" + name,
                  "expected " + value_type,
                  pos,
                )
              }
            None =>
              add_finding(
                findings,
                "DefinedAttributeParent",
                path + "/" + name,
                "user attribute used outside declared group",
                pos,
              )
          }
        }
      Complex("include_file", args, pos) => {
        ignore(include_name(args, pos)) catch {
          error => {
            findings.push(finding(error, path + "/include_file"))
            continue
          }
        }
        add_finding(
          findings,
          "UnresolvedInclude",
          path + "/include_file",
          "supply an explicit source map before checking expanded structure",
          pos,
        )
      }
      Complex(name, _, pos) =>
        if attrs.contains(name) {
          add_finding(
            findings,
            "DefinedAttributeForm",
            path + "/" + name,
            "declared simple attributes require name : value;",
            pos,
          )
        }
    }
  }
}

///|
/// Check implemented format rules and report separate format/evaluation coverage.
/// complete_conformance remains false until the full edition checklist is closed.
pub fn compatibility_report(
  root : Group,
  standard~ : StandardEdition = Liberty2017_06,
) -> CompatibilityReport raise LibertyError {
  ignore(write_liberty(root))
  let attrs : Map[String, Map[String, String]] = Map([])
  let groups : Map[String, String] = Map([])
  let findings = []
  collect_declarations(root, attrs, groups, findings)
  findings.append(collect_standard_findings(root))
  let counts : Map[String, Int32] = Map([])
  let modes : Map[String, String] = Map([])
  inspect_format(
    root,
    "",
    "/library(" + root.name() + ")",
    attrs,
    groups,
    counts,
    modes,
    findings,
  )
  let keys = counts.keys().to_array()
  keys.sort_by(lexical_compare)
  let features = keys.map(key => {
    (
      { family: key, occurrences: counts[key], evaluation: modes[key], } :
      FormatFeature)
  })
  {
    standard,
    library: root.name(),
    findings,
    features,
    roundtrip_verified: true,
    complete_conformance: false,
  }
}

///|
pub fn compatibility_json(report : CompatibilityReport) -> Json {
  let errors = report.findings.filter(f => f.severity == Error).length()
  {
    "schema": "moonliberty.compatibility.v1",
    "target_standard": Json(report.standard.label()),
    "version_detection": "caller_declared",
    "library": Json(report.library),
    "implemented_checks_passed": Json(errors == 0),
    "complete_standard_conformance": Json(report.complete_conformance),
    "roundtrip_verified": Json(report.roundtrip_verified),
    "implemented_rule_ids": Json(standard_rule_ids()),
    "rule_inventory_exhaustive": false,
    "errors": Json(errors),
    "warnings": Json(report.findings.length() - errors),
    "features": Json(
      report.features.map(feature => {
        (
          {
            "family": Json(feature.family),
            "occurrences": Json(feature.occurrences),
            "evaluation": Json(feature.evaluation),
          } : Json)
      }),
    ),
    "findings": findings_json(report.findings),
    "conformance_contract": "docs/STANDARD_CONFORMANCE.md",
  }
}
