///|
pub extend TimingArc with @debug.Debug::{to_repr}

///|
pub extend Pin with @debug.Debug::{to_repr}

///|
pub extend Cell with @debug.Debug::{to_repr}

///|
pub extend Library with @debug.Debug::{to_repr}

///|
pub extend Inventory with Eq::{equal, not_equal}

///|
pub extend Inventory with @debug.Debug::{to_repr}
