(() => {
  const toggle = document.querySelector('#languageToggle');
  const nodes = document.querySelectorAll('[data-zh][data-en]');
  let language = 'zh';

  function render() {
    nodes.forEach((node) => {
      node.innerHTML = node.dataset[language];
    });
    document.documentElement.lang = language === 'zh' ? 'zh-Hant' : 'en';
    toggle.textContent = language === 'zh' ? 'EN' : '中';
    toggle.setAttribute('aria-label', language === 'zh' ? 'Switch to English' : '切換至繁體中文');
  }

  toggle.addEventListener('click', () => {
    language = language === 'zh' ? 'en' : 'zh';
    render();
  });
  render();
})();
