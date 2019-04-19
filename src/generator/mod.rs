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

    fn build(&mut self) -> String {
        let mut result = "".to_string();
        for cmd in &self.cmds {
            match cmd {
                BfCmd::Inc => result.push('+'),
                BfCmd::Dec => result.push('-'),
                BfCmd::Right => result.push('>'),
                BfCmd::Left => result.push('<'),
                BfCmd::Open => result.push('['),
                BfCmd::Close => result.push(']'),
                BfCmd::Get => result.push(','),
                BfCmd::Put => result.push('.'),
            }
        }
        result
    }

    fn raw(&mut self, code: &str) {
        for c in code.chars() {
            match c {
                '+' => self.raw_inc(),
                '-' => self.raw_dec(),
                '>' => self.raw_right(),
                '<' => self.raw_left(),
                '[' => self.raw_open(),
                ']' => self.raw_close(),
                ',' => self.raw_get(),
                '.' => self.raw_put(),
                _ => {}
            }
        }
    }

    fn raw_inc(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Dec) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Inc);
        }
    }

    fn raw_dec(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Inc) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Dec);
        }
    }

    fn raw_right(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Left) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Right);
        }
    }

    fn raw_left(&mut self) {
        if self.cmds.last() == Some(&BfCmd::Right) {
            self.cmds.pop();
        } else {
            self.cmds.push(BfCmd::Left);
        }
    }

    fn raw_open(&mut self) {
        self.cmds.push(BfCmd::Open);
    }

    fn raw_close(&mut self) {
        self.cmds.push(BfCmd::Close);
    }

    fn raw_get(&mut self) {
        self.cmds.push(BfCmd::Get);
    }

    fn raw_put(&mut self) {
        self.cmds.push(BfCmd::Put);
    }
}

pub fn generate() -> String {
    let mut gen = Generator::new();
    gen.raw(">+++++++++[<++++++++>-]<.>+++++++[<++++>-]<+.+++++++..+++.[-]>++++++++[<++++>-]<.>+++++++++++[<+++++>-]<.>++++++++[<+++>-]<.+++.------.--------.[-]>++++++++[<++++>-]<+.[-]++++++++++.");
    gen.build()
}
