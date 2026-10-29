///|
fn format_report(
  body : String,
) -> @liberty.CompatibilityReport raise @liberty.LibertyError {
  @liberty.compatibility_report(
    @liberty.parse_liberty("library(x){" + body + "}"),
  )
}

///|
fn format_codes(body : String) -> Array[String] raise @liberty.LibertyError {
  format_report(body).findings.map(f => f.code)
}

///|
test "standard target is explicit and not inferred from date" {
  assert_eq(@liberty.parse_standard("2017.06").label(), "Liberty 2017.06")
  assert_eq(@liberty.parse_standard("liberty-2017.06"), @liberty.Liberty2017_06)
}

///|
test "unknown standards are rejected instead of guessed" {
  try @liberty.parse_standard("2020.09") catch {
    @liberty.LibertyError(code, _, _) => assert_eq(code, "UnsupportedStandard")
  } noraise {
    _ => fail("version must be recognized")
  }
}

///|
test "format success never claims complete standard conformance" {
  let report = format_report("date:\"2024.01\";cell(C){}")
  assert_eq(report.standard.label(), "Liberty 2017.06")
  assert_true(report.roundtrip_verified)
  assert_false(report.complete_conformance)
  assert_eq(report.findings.length(), 0)
}

///|
test "valid declared string attribute is checked and retained" {
  assert_eq(format_codes("define(label,cell,string);cell(C){label:\"abc\";}"), [])
}

///|
test "declared string attribute rejects bare values" {
  assert_true(
    format_codes("define(label,cell,string);cell(C){label:abc;}").contains(
      "DefinedAttributeType",
    ),
  )
}

///|
test "declared integer attribute rejects fractional values" {
  assert_true(
    format_codes("define(rank,cell,integer);cell(C){rank:1.2;}").contains(
      "DefinedAttributeType",
    ),
  )
}

///|
test "integer check does not overflow native int conversion" {
  assert_eq(
    format_codes("define(rank,cell,integer);cell(C){rank:4294967296;}"),
    [],
  )
}

///|
test "declared float rejects non finite numbers" {
  assert_true(
    format_codes("define(weight,cell,float);cell(C){weight:NaN;}").contains(
      "DefinedAttributeType",
    ),
  )
}

///|
test "declared boolean has true and false values" {
  assert_eq(
    format_codes(
      "define(flag,cell,boolean);cell(A){flag:true;}cell(B){flag:false;}",
    ),
    [],
  )
}

///|
test "declared boolean rejects truthy spelling" {
  assert_true(
    format_codes("define(flag,cell,boolean);cell(C){flag:1;}").contains(
      "DefinedAttributeType",
    ),
  )
}

///|
test "user attributes cannot silently escape declared scope" {
  assert_true(
    format_codes("define(label,cell,string);label:\"x\";").contains(
      "DefinedAttributeParent",
    ),
  )
}

///|
test "same attribute may have different valid group scopes" {
  assert_eq(
    format_codes(
      "define(tag,cell,string);define(tag,pin,integer);cell(C){tag:\"x\";pin(A){tag:2;}}",
    ),
    [],
  )
}

///|
test "bad declaration arity and types are visible" {
  assert_true(format_codes("define(a,cell);").contains("InvalidDefine"))
  assert_true(format_codes("define(a,cell,double);").contains("InvalidDefine"))
}

///|
test "duplicate attribute definition is diagnosed" {
  assert_true(
    format_codes("define(a,cell,float);define(a,cell,float);").contains(
      "DuplicateDefine",
    ),
  )
}

///|
test "declared extension group accepts its declared parent" {
  assert_eq(
    format_codes("define_group(meta,cell);cell(C){meta(x){note:\"retained\";}}"),
    [],
  )
}

///|
test "declared extension group rejects wrong parent" {
  assert_true(
    format_codes("define_group(meta,cell);meta(x){}").contains(
      "DefinedGroupParent",
    ),
  )
}

///|
test "duplicate and malformed group declarations are diagnosed" {
  assert_true(
    format_codes("define_group(meta);").contains("InvalidDefineGroup"),
  )
  assert_true(
    format_codes("define_group(meta,cell);define_group(meta,cell);").contains(
      "DuplicateDefineGroup",
    ),
  )
}

///|
test "unknown vendor groups remain visible without being called understood" {
  let report = format_report("vendor(x){magic:42;}")
  assert_true(
    report.findings.any(f => {
      f.code == "UnclassifiedGroup" && f.severity is Warning
    }),
  )
  assert_true(
    report.features.any(f => {
      f.family == "unclassified_extension" && f.evaluation == "preserved_only"
    }),
  )
}

///|
test "CCS LVF buses and sequential data are preserved not evaluated" {
  let report = format_report(
    "cell(C){bus(A){bus_type:V;}ff(IQ,IQN){clocked_on:\"CK\";}pin(Y){timing(){output_current_rise(T){vector(V){values(\"0,1\");}}ocv_mean_shift_cell_rise(T){values(\"0\");}}}}",
  )
  for
    family in ["bus_bundle", "sequential", "variation_lvf", "current_waveform"] {
    assert_true(
      report.features.any(f => {
        f.family == family && f.evaluation == "preserved_only"
      }),
    )
  }
}

///|
test "unresolved includes prevent implemented format checks from passing" {
  assert_true(format_codes("include_file(data);").contains("UnresolvedInclude"))
}

///|
test "resolved includes are checked in the original parent scope" {
  let root = @liberty.parse_liberty_sources(
    "library(x){define(rank,cell,integer);cell(C){include_file(a);}}",
    Map([("a", "rank:0.5;")]),
  )
  assert_true(
    @liberty.compatibility_report(root).findings.any(f => {
      f.code == "DefinedAttributeType"
    }),
  )
}

///|
test "compatibility JSON contains explicit complete conformance false" {
  let json = @liberty.compatibility_json(format_report("cell(C){}")).stringify()
  assert_true(json.contains("\"complete_standard_conformance\":false"))
  assert_true(json.contains("\"target_standard\":\"Liberty 2017.06\""))
}

///|
test "integer declarations do not round huge fractions into integers" {
  assert_true(
    format_codes("define(rank,cell,integer);cell(C){rank:9007199254740992.5;}").contains(
      "DefinedAttributeType",
    ),
  )
}

///|
test "integer declarations accept arbitrarily long signed digit literals" {
  assert_eq(
    format_codes(
      "define(rank,cell,integer);cell(C){rank:-123456789012345678901234567890;}",
    ),
    [],
  )
}

///|
test "integer declarations reject decimal and exponent float spelling" {
  assert_true(
    format_codes("define(rank,cell,integer);cell(C){rank:1.0;}").contains(
      "DefinedAttributeType",
    ),
  )
  assert_true(
    format_codes("define(rank,cell,integer);cell(C){rank:1e0;}").contains(
      "DefinedAttributeType",
    ),
  )
}

///|
test "out of scope user attribute emits one finding regardless of declared parents" {
  let body = StringBuilder()
  for i in 0..<64 {
    body.write_string("define(rank,p\{i},integer);")
  }
  body.write_string("rank:1;")
  let report = format_report(body.to_string())
  assert_eq(
    report.findings.filter(f => f.code == "DefinedAttributeParent").length(),
    1,
  )
}

///|
test "declaration indexes keep name and parent components separate" {
  assert_eq(
    format_codes(
      "define_group(part/cell,library);define(tag/part,cell,integer);define(tag,part/cell,string);cell(C){tag/part:2;}part/cell(M){tag:\"ok\";}",
    ),
    [],
  )
}

///|
test "many user declarations still resolve every value and preserve first definitions" {
  let body = StringBuilder()
  for i in 0..<512 {
    body.write_string("define(a\{i},cell,integer);")
  }
  body.write_string("define(a0,cell,string);cell(C){")
  for i in 0..<512 {
    body.write_string("a\{i}:\{i};")
  }
  body.write_string("}")
  let report = format_report(body.to_string())
  assert_eq(
    report.findings.filter(f => f.code == "DuplicateDefine").length(),
    1,
  )
  assert_false(report.findings.any(f => f.code == "DefinedAttributeType"))
}

///|
test "declared simple attributes cannot bypass type checks with complex syntax" {
  assert_true(
    format_codes("define(rank,cell,integer);cell(C){rank(1.5);}").contains(
      "DefinedAttributeForm",
    ),
  )
  assert_eq(format_codes("cell(C){vendor_values(1.5);}"), [])
}
