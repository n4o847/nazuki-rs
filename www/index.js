import "./style.css";

const $result = document.getElementById("result");
const $length  = document.getElementById("length");

async function load() {
  const nazuki = await import('nazuki');

  $result.value = nazuki.generate();
  $length.textContent = $result.value.length;
}

try {
  load();
} catch (e) {
  console.error(e);
}
