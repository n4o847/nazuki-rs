import "./style.css";

const $result = document.getElementById("result");

async function load() {
  const nazuki = await import('nazuki');

  $result.value = nazuki.generate();
}

try {
  load();
} catch (e) {
  console.error(e);
}
