#[derive(Clone, PartialEq, Eq, Hash)]
pub enum Inst {
    I32Const(i32),
    I32Not,
    I32And,
    I32Or,
    I32Xor,
    I32Shl,
    I32Inc,
    I32Print,
}
