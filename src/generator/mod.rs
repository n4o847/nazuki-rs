use isa::Inst;
use std::collections::HashMap;

macro_rules! mem {
    () => {};
    ($x:ident : $a:tt, $($rest:tt)*) => {
        let $x: isize = $a;
        mem! { $($rest)* }
    };
    ($x:ident : $a:tt .. $b:tt, $($rest:tt)*) => {
        let $x: Vec<isize> = ($a..$b).collect();
        mem! { $($rest)* }
    };
    ($x:ident : $a:tt ..= $b:tt, $($rest:tt)*) => {
        let $x: Vec<isize> = ($a..=$b).collect();
        mem! { $($rest)* }
    };
}

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

struct Generator {
    cmds: Vec<BfCmd>,
}

impl Generator {
    fn new() -> Self {
        Generator { cmds: Vec::new() }
    }

    fn build(&self) -> String {
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
        mem! {
            tmp: 0,
            cmd: 1,
        }

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
                self.add(cmd + i, (bits >> i) & 1);
            }
            self.right(9);
        }
        self.left(9);
        self.bf_inc();
        self.r#while(tmp, |s| {
            s.sub(tmp, 1);
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

    fn right(&mut self, x: isize) {
        for _ in 0..x {
            self.bf_right();
        }
        for _ in x..0 {
            self.bf_left();
        }
    }

    fn left(&mut self, x: isize) {
        self.right(-x);
    }

    fn enter(&mut self, p: isize) {
        self.right(p);
    }

    fn exit(&mut self, p: isize) {
        self.left(p);
    }

    fn add(&mut self, p: isize, x: i32) {
        self.enter(p);
        for _ in 0..x {
            self.bf_inc();
        }
        for _ in x..0 {
            self.bf_dec();
        }
        self.exit(p);
    }

    fn sub(&mut self, p: isize, x: i32) {
        self.add(p, -x);
    }

    fn r#while<F: FnMut(&mut Self)>(&mut self, p: isize, mut block: F) {
        self.enter(p);
        self.bf_open();
        self.exit(p);
        block(self);
        self.enter(p);
        self.bf_close();
        self.exit(p);
    }

    fn set(&mut self, p: isize, x: i32) {
        self.r#while(p, |s| {
            s.sub(p, 1);
        });
        self.add(p, x);
    }

    fn r#if<F1: FnMut(&mut Self), F2: FnMut(&mut Self)>(
        &mut self,
        flg: isize,
        tmp: isize,
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

    fn i32_const(&mut self, a: i32) {
        mem! {
            head: 0,
            body: 1..=32,
            terminus: 33,
        }

        self.add(head, 1);
        for i in 0..32 {
            self.add(body[i], a >> i & 1);
        }
        self.enter(terminus);
    }

    fn i32_and(&mut self) {
        mem! {
            start_point: 66,
            _a_head: 0,
            a_body: 1..=32,
            b_head: 33,
            b_body: 34..=65,
            end_point: 33,
        }

        self.exit(start_point);
        for i in (0..32).rev() {
            self.sub(b_body[i], 1);
            self.r#while(b_body[i], |s| {
                s.add(b_body[i], 1);
                s.set(a_body[i], 0);
            });
        }
        self.sub(b_head, 1);
        self.enter(end_point);
    }

    fn i32_or(&mut self) {
        mem! {
            start_point: 66,
            _a_head: 0,
            a_body: 1..=32,
            b_head: 33,
            b_body: 34..=65,
            end_point: 33,
        }

        self.exit(start_point);
        for i in (0..32).rev() {
            self.r#while(b_body[i], |s| {
                s.sub(b_body[i], 1);
                s.set(a_body[i], 1);
            });
        }
        self.sub(b_head, 1);
        self.enter(end_point);
    }

    fn i32_xor(&mut self) {
        mem! {
            start_point: 66,
            a_head: 0,
            a_body: 1..=32,
            b_head: 33,
            b_body: 34..=65,
            end_point: 33,
        }

        self.exit(start_point);
        // rev のほうが若干短い？
        for i in (0..32).rev() {
            self.r#while(b_body[i], |s| {
                s.sub(b_body[i], 1);
                // i < 13 で分けると生成コードが一番短くなる。
                let temp = if i < 13 { a_head } else { b_head };
                s.r#while(a_body[i], |t| {
                    t.sub(a_body[i], 1);
                    t.sub(temp, 1);
                });
                s.r#while(temp, |t| {
                    t.sub(temp, 1);
                    t.add(a_body[i], 1);
                });
                s.add(temp, 1);
            });
        }
        self.sub(b_head, 1);
        self.enter(end_point);
    }

    fn i32_shl(&mut self) {
        mem! {
            start_point: 66,
            _a_head: 0,
            a_body: 1..=32,
            b_head: 33,
            b_body: 34..=65,
            end_point: 33,
        }

        self.exit(start_point);
        for i in (5..32).rev() {
            self.set(b_body[i], 0);
        }
        for i in (1..=4).rev() {
            self.r#while(b_body[i], |s| {
                s.sub(b_body[i], 1);
                s.add(b_body[0], 1 << i);
            });
        }
        self.r#while(b_body[0], |s| {
            s.sub(b_body[0], 1);
            s.set(a_body[31], 0);
            for i in (0..31).rev() {
                s.r#while(a_body[i], |t| {
                    t.sub(a_body[i], 1);
                    t.add(a_body[i + 1], 1);
                });
            }
        });
        self.sub(b_head, 1);
        self.enter(end_point);
    }
}

pub fn generate() -> String {
    let mut gen = Generator::new();
    gen.raw(">+++++++++[<++++++++>-]<.>+++++++[<++++>-]<+.+++++++..+++.[-]>++++++++[<++++>-]<.>+++++++++++[<+++++>-]<.>++++++++[<+++>-]<.+++.------.--------.[-]>++++++++[<++++>-]<+.[-]++++++++++.");
    gen.build()
}
