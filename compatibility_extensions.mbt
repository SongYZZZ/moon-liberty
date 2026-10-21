///|
pub extend StandardEdition with Eq::{equal, not_equal}

///|
pub extend StandardEdition with @debug.Debug::{to_repr}

///|
pub extend FormatFeature with Eq::{equal, not_equal}

///|
pub extend FormatFeature with @debug.Debug::{to_repr}

///|
pub extend CompatibilityReport with @debug.Debug::{to_repr}
