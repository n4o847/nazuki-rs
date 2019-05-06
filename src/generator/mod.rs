use isa::Inst;
use std::collections::HashMap;

#[derive(PartialEq)]
enum BfCmd {
    Inc,
    Dec,
    Right,
    Left,
    Open,
    Close,
    Get,
    Put,
}

struct Ptr(i32);

struct Generator {
    cmds: Vec<BfCmd>,
}

impl Generator {
    fn new() -> Self {
        Generator { cmds: Vec::new() }
    }

    fn build(&mut self) -> String {
        let mut result = String::new();
        for cmd in &self.cmds {
            let ch = match cmd {
                BfCmd::Inc => '+',
                BfCmd::Dec => '-',
                BfCmd::Right => '>',
                BfCmd::Left => '<',
                BfCmd::Open => '[',
                BfCmd::Close => ']',
                BfCmd::Get => ',',
                BfCmd::Put => '.',
            };
            result.push(ch);
        }
        result
    }

    fn raw(&mut self, code: &str) {
        for c in code.chars() {
            match c {
                '+' => self.bf_inc(),
                '-' => self.bf_dec(),
                '>' => self.bf_right(),
                '<' => self.bf_left(),
                '[' => self.bf_open(),
                ']' => self.bf_close(),
                ',' => self.bf_get(),
                '.' => self.bf_put(),
                _ => {}
            }
        }
    }

    fn main(&mut self, program: &[Inst]) -> Result<String, &str> {
        let tmp = 0;
        let cmd = 1;

        let mut inst_map = HashMap::new();

        self.bf_dec();
        self.right(9);
        for inst in program.iter().rev() {
            let bits = if let Some(&bits) = inst_map.get(inst) {
                bits
            } else {
                let bits = inst_map.len() as i32;
                inst_map.insert(inst, bits);
                bits
            };
            if bits > 256 {
                return Err("too large set of instructions");
            }
            for i in 0..8 {
                self.add(&Ptr(cmd + i), (bits >> i) & 1);
            }
            self.right(9);
        }
        self.left(9);
        self.bf_inc();
        self.r#while(&Ptr(tmp), |s| {
            s.sub(&Ptr(tmp), 1);
            // TODO
        });
        return Ok(self.build());
    }

    fn bf_inc(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Dec) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Inc);
        }
    }

    fn bf_dec(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Inc) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Dec);
        }
    }

    fn bf_right(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Left) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Right);
        }
    }

    fn bf_left(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Right) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Left);
        }
    }

    fn bf_open(&mut self) {
        self.cmds.push(BfCmd::Open);
    }

    fn bf_close(&mut self) {
        self.cmds.push(BfCmd::Close);
    }

    fn bf_get(&mut self) {
        self.cmds.push(BfCmd::Get);
    }

    fn bf_put(&mut self) {
        self.cmds.push(BfCmd::Put);
    }

    fn right(&mut self, x: i32) {
        for _ in 0..x {
            self.bf_right();
        }
        for _ in x..0 {
            self.bf_left();
        }
    }

    fn left(&mut self, x: i32) {
        self.right(-x);
    }

    fn enter(&mut self, p: &Ptr) {
        self.right(p.0);
    }

    fn exit(&mut self, p: &Ptr) {
        self.left(p.0);
    }

    fn add(&mut self, p: &Ptr, x: i32) {
        self.enter(p);
        for _ in 0..x {
            self.bf_inc();
        }
        for _ in x..0 {
            self.bf_dec();
        }
        self.exit(p);
    }

    fn sub(&mut self, p: &Ptr, x: i32) {
        self.add(p, -x);
    }

    fn r#while<F: FnMut(&mut Self)>(&mut self, p: &Ptr, mut block: F) {
        self.enter(p);
        self.bf_open();
        self.exit(p);
        block(self);
        self.enter(p);
        self.bf_close();
        self.exit(p);
    }

    fn set(&mut self, p: &Ptr, x: i32) {
        self.r#while(p, |s| {
            s.bf_dec();
        });
        self.add(p, x);
    }

    fn r#if<F1: FnMut(&mut Self), F2: FnMut(&mut Self)>(
        &mut self,
        flg: &Ptr,
        tmp: &Ptr,
        mut cons: F1,
        mut alt: F2,
    ) {
        self.r#while(flg, |s| {
            cons(s);
            s.sub(tmp, 1);
            s.sub(flg, 1);
        });
        self.add(flg, 1);
        self.add(tmp, 1);
        self.r#while(tmp, |s| {
            s.sub(tmp, 1);
            s.sub(flg, 1);
            alt(s);
        });
    }
}

pub fn generate() -> String {
    let mut gen = Generator::new();
    gen.raw(">+++++++++[<++++++++>-]<.>+++++++[<++++>-]<+.+++++++..+++.[-]>++++++++[<++++>-]<.>+++++++++++[<+++++>-]<.>++++++++[<+++>-]<.+++.------.--------.[-]>++++++++[<++++>-]<+.[-]++++++++++.");
    gen.build()
}
