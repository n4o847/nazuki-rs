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

    fn get(&mut self, p: isize) {
        self.enter(p);
        self.bf_get();
        self.exit(p);
    }

    fn put(&mut self, p: isize) {
        self.enter(p);
        self.bf_put();
        self.exit(p);
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

    // 呼び出した場所の左隣のセルの値が 0 であること
    // 繰り上がりに注意
    fn incs(&mut self, p: isize) {
        self.enter(p);
        self.raw("[>]+<[-<]>");
        self.exit(p);
    }

    // 呼び出した場所の左隣のセルの値が 0 であること
    // 繰り下がりに注意
    fn decs(&mut self, p: isize) {
        self.enter(p);
        self.raw("-[++>-]<[<]>");
        self.exit(p);
    }

    fn main(&mut self, program: Vec<Inst>) -> Result<String, &str> {
        mem! {
            tmp: 0,
            cmd: 1..=8,
        }

        let mut inst_map = HashMap::new();
        let mut inst_vec = Vec::new();

        self.bf_dec();
        self.right(9);
        for inst in program.iter().rev() {
            let bits = if let Some(&bits) = inst_map.get(inst) {
                bits
            } else {
                let bits = inst_map.len() as i32;
                inst_map.insert(inst, bits);
                inst_vec.push(inst);
                bits
            };
            if bits > 256 {
                return Err("too large set of instructions");
            }
            for i in 0..8 {
                self.add(cmd[i], bits >> i & 1);
            }
            self.right(9);
        }
        self.left(9);
        self.bf_inc();
        self.r#while(tmp, |s| {
            s.sub(tmp, 1);
            s.inst_branch(7, 0, &inst_vec[..]);
            s.add(tmp, 1);
            s.left(9);
            s.add(tmp, 1);
        });
        return Ok(self.build());
    }

    fn inst_branch(&mut self, i: i32, bit: i32, inst_vec: &[&Inst]) {
        mem! {
            tmp: 0,
            cmd: 1..=8,
        }

        let len = inst_vec.len() as i32;
        if len == 0 {
            return;
        } else if i < 0 {
            if let Some(inst) = inst_vec.get(bit as usize) {
                self.inst_put(inst);
            }
        } else if len <= bit | 1 << i {
            self.inst_branch(i - 1, bit, inst_vec);
        } else {
            self.r#if(
                cmd[i as usize],
                tmp,
                |s| {
                    s.inst_branch(i - 1, bit | 1 << i, inst_vec);
                },
                |s| {
                    s.inst_branch(i - 1, bit, inst_vec);
                },
            );
        }
    }

    fn inst_put(&mut self, inst: &Inst) {
        self.ip_to_sp();
        match *inst {
            Inst::I32Const(a) => self.i32_const(a),
            Inst::I32Not => self.i32_not(),
            Inst::I32And => self.i32_and(),
            Inst::I32Or => self.i32_or(),
            Inst::I32Xor => self.i32_xor(),
            Inst::I32Shl => self.i32_shl(),
            Inst::I32Inc => self.i32_inc(),
            Inst::I32Print => self.i32_print(),
        }
        self.sp_to_ip();
    }

    fn sp_to_ip(&mut self) {
        self.left(33);
        self.bf_open();
        self.left(33);
        self.bf_close();
        self.left(9);
        self.bf_open();
        self.left(9);
        self.bf_close();
    }

    fn ip_to_sp(&mut self) {
        self.right(9);
        self.bf_open();
        self.right(9);
        self.bf_close();
        self.right(33);
        self.bf_open();
        self.right(33);
        self.bf_close();
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

    fn i32_not(&mut self) {
        mem! {
            start_point: 33,
            _head: 0,
            body: 1..=32,
            helper: 2..=33,
            end_point: 33,
        }

        self.exit(start_point);
        for i in (0..32).rev() {
            self.add(helper[i], 1);
            self.r#while(body[i], |s| {
                s.sub(body[i], 1);
                s.sub(helper[i], 1);
            });
        }
        for i in 0..32 {
            self.r#while(helper[i], |s| {
                s.sub(helper[i], 1);
                s.add(body[i], 1);
            });
        }
        self.enter(end_point);
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

    fn i32_inc(&mut self) {
        mem! {
            start_point: 33,
            head: 0,
            body: 1..=32,
            carry: 33,
            end_point: 0,
        }

        self.exit(start_point);
        self.sub(head, 1);
        self.incs(body[0]);
        self.add(head, 1);
        self.set(carry, 0);
        self.enter(end_point);
    }

    fn i32_print(&mut self) {
        mem! {
            start_point: 33,
            head: 0,
            body: 1..=32,
            temp: 33,
            temp_0: 34,
            end_point: 0,
        }

        self.exit(start_point);
        // 負数用の処理 ここから
        self.r#while(body[31], |s| {
            s.add(temp, 45);
            s.put(temp);
            s.set(temp, 0);
            s.enter(start_point);
            s.i32_not();
            s.exit(start_point);
            s.sub(head, 1);
            s.incs(body[0]);
            s.add(head, 1);
            s.r#while(body[31], |s| {
                s.sub(body[31], 1);
                s.add(temp_0, 1);
            });
        });
        self.r#while(temp_0, |s| {
            s.sub(temp_0, 1);
            s.add(body[31], 1);
        });
        // 負数用の処理 ここまで
        // 2 ** 31 に注意
        for i in 0..32 {
            let mut digits = (1 << i) as u32;
            self.r#while(body[i], |s| {
                s.sub(body[i], 1);
                let mut j = 0;
                while digits > 0 {
                    let d = (digits % 10) as i32;
                    s.add(temp + 3 * j, d);
                    digits /= 10;
                    j += 1;
                }
            });
        }
        for j in 0..9 {
            let dividend = temp + 3 * j;
            let divisor = temp + 3 * j + 1;
            let remainder = temp + 3 * j + 2;
            let _quotient = temp + 3 * j + 3;
            self.add(divisor, 10);
            self.enter(dividend);
            // https://esolangs.org/wiki/Brainfuck_algorithms#Divmod_algorithm
            // >n d
            self.raw("[->-[>+>>]>[+[-<+>]>+>>]<<<<<]");
            // >0 d-n%d n%d n/d
            self.exit(dividend);
            self.set(divisor, 0);
            self.r#while(remainder, |s| {
                s.sub(remainder, 1);
                s.add(dividend, 1);
            });
        }
        for j in (1..10).rev() {
            let s1 = temp + 3 * j - 2;
            let t0 = temp + 3 * j;
            let t1 = temp + 3 * j + 1;
            let t2 = temp + 3 * j + 2;
            self.r#while(t0, |s| {
                s.sub(t0, 1);
                s.add(t1, 1);
                s.add(t2, 1);
            });
            self.r#while(t1, |s| {
                s.r#while(t1, |s| {
                    s.set(t1, 0);
                    s.add(s1, 1);
                });
                s.add(t2, 48);
                s.put(t2);
                s.set(t2, 0);
            });
        }
        {
            let t0 = temp;
            let t1 = temp + 1;
            self.set(t1, 0);
            self.add(t0, 48);
            self.put(t0);
            self.set(t0, 0);
        }
        self.sub(head, 1);
        self.enter(end_point);
    }
}

#[test]
fn i32_print_keep_within_range() {
    let mut cells = vec![0; 10];
    for i in 0..32 {
        let mut digits = (1 << i) as u32;
        let mut j = 0;
        while digits > 0 {
            let d = (digits % 10) as i32;
            cells[j] += d;
            digits /= 10;
            j += 1;
        }
    }
    let mut carry = 0;
    for value in cells {
        if value + carry >= 256 {
            panic!("overflow!!");
        }
        carry = (value + carry) / 10;
    }
}

pub fn generate() -> String {
    let mut gen = Generator::new();
    gen.main(vec![Inst::I32Const(334), Inst::I32Print]).unwrap()
}
