#![forbid(unsafe_code)]

//! nosd-theme library: color science, quantizers, scheme expansion and the
//! Matugen-compatible template renderer backing the nosd-theme binary.

pub mod color;
pub mod contrast;
pub mod hct;
pub mod image;
pub mod material;
pub mod palette;
pub mod quantizer;
pub mod renderer;
pub mod scheme;
pub mod theme;
