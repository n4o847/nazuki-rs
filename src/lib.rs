extern crate wasm_bindgen;
use wasm_bindgen::prelude::*;

mod generator;
pub mod isa;

#[wasm_bindgen]
pub fn generate() -> String {
    generator::generate()
}
