const buttons = document.querySelectorAll('[data-image]');
const image = document.getElementById('gallery-image');
const caption = document.getElementById('gallery-caption');
for (const button of buttons) {
  button.addEventListener('click', () => {
    image.src = `assets/${button.dataset.image}`;
    image.alt = `${button.dataset.caption} wallpaper example`;
    caption.textContent = button.dataset.caption;
    for (const choice of buttons) choice.setAttribute('aria-pressed', String(choice === button));
  });
}
