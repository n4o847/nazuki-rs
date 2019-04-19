const nazuki = import('nazuki');

nazuki
  .then(m => {
    console.log(m.generate());
  })
  .catch(console.error);
