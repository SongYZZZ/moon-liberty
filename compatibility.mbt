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
  occurrences : Int
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
priv struct UserAttribute {
  name : String
  parent : String
  value_type : String
}

///|
priv struct UserGroup {
  name : String
  parent : String
}

///|
fn declaration_argument(arguments : Array[Array[Atom]], index : Int) -> String? {
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
  attrs : Array[UserAttribute],
  groups : Array[UserGroup],
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
        } else if attrs.any(a => a.name == name && a.parent == parent) {
          add_finding(
            findings,
            "DuplicateDefine",
            "/library/define/" + name,
            "attribute definition repeated",
            pos,
          )
        } else {
          attrs.push({ name, parent, value_type, })
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
        } else if groups.any(g => g.name == name) {
          add_finding(
            findings,
            "DuplicateDefineGroup",
            "/library/define_group/" + name,
            "group definition repeated",
            pos,
          )
        } else {
          groups.push({ name, parent, })
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
  attrs : Array[UserAttribute],
  groups : Array[UserGroup],
  counts : Map[String, Int],
  modes : Map[String, String],
  findings : Array[Finding],
) -> Unit {
  let (family, mode) = feature_family(group.kind)
  counts[family] = counts.get(family).unwrap_or(0) + 1
  modes[family] = mode
  if family == "unclassified_extension" {
    let defined = groups.any(g => g.name == group.kind)
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
  for definition in groups {
    if definition.name == group.kind && definition.parent != parent {
      add_finding(
        findings,
        "DefinedGroupParent",
        path,
        "declared parent is " + definition.parent,
        group.position,
      )
    }
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
        for definition in attrs {
          if definition.name == name {
            if definition.parent != group.kind {
              // Only diagnose scope if the name has no matching declaration here.
              if !attrs.any(a => a.name == name && a.parent == group.kind) {
                add_finding(
                  findings,
                  "DefinedAttributeParent",
                  path + "/" + name,
                  "user attribute used outside declared group",
                  pos,
                )
              }
            } else if !attribute_value_valid(definition.value_type, atoms) {
              add_finding(
                findings,
                "DefinedAttributeType",
                path + "/" + name,
                "expected " + definition.value_type,
                pos,
              )
            }
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
      _ => ()
    }
  }
}

///|
/// Check implemented format rules and report separate format/evaluation coverage.
/// complete_conformance remains false until the full edition checklist is closed.
pub fn compatibility_report(
  root : Group,
  standard? : StandardEdition = Liberty2017_06,
) -> CompatibilityReport raise LibertyError {
  ignore(write_liberty(root))
  let attrs = []
  let groups = []
  let findings = []
  collect_declarations(root, attrs, groups, findings)
  findings.append(collect_standard_findings(root))
  let counts : Map[String, Int] = Map([])
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
    "target_standard": report.standard.label().to_json(),
    "version_detection": "caller_declared",
    "library": report.library.to_json(),
    "implemented_checks_passed": (errors == 0).to_json(),
    "complete_standard_conformance": report.complete_conformance.to_json(),
    "roundtrip_verified": report.roundtrip_verified.to_json(),
    "implemented_rule_ids": standard_rule_ids().to_json(),
    "rule_inventory_exhaustive": false,
    "errors": errors.to_json(),
    "warnings": (report.findings.length() - errors).to_json(),
    "features": report.features
    .map(feature => {
      (
        {
          "family": feature.family.to_json(),
          "occurrences": feature.occurrences.to_json(),
          "evaluation": feature.evaluation.to_json(),
        } : Json)
    })
    .to_json(),
    "findings": findings_json(report.findings),
    "conformance_contract": "docs/STANDARD_CONFORMANCE.md",
  }
}
