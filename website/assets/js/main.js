// ==================== MAIN JAVASCRIPT ====================

document.addEventListener('DOMContentLoaded', () => {
  // Mobile Navigation Toggle
  initMobileNav();

  // Scroll animations
  initScrollAnimations();

  // Platform tabs (Getting Started section)
  initPlatformTabs();

  // Sticky header on scroll
  initStickyHeader();

  // Copy code button functionality
  initCopyButtons();
});

// ==================== MOBILE NAVIGATION ====================
function initMobileNav() {
  const navToggle = document.getElementById('nav-toggle');
  const navMenu = document.getElementById('nav-menu');
  const navLinks = document.querySelectorAll('.nav__link');

  if (navToggle) {
    navToggle.addEventListener('click', () => {
      navMenu.classList.toggle('active');
    });
  }

  // Close menu when clicking on nav links
  navLinks.forEach(link => {
    link.addEventListener('click', () => {
      navMenu.classList.remove('active');
    });
  });

  // Close menu when clicking outside
  document.addEventListener('click', (e) => {
    if (!navMenu.contains(e.target) && !navToggle.contains(e.target)) {
      navMenu.classList.remove('active');
    }
  });
}

// ==================== SCROLL ANIMATIONS ====================
function initScrollAnimations() {
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -100px 0px'
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('active');
      }
    });
  }, observerOptions);

  // Observe all elements with scroll-animate class
  const animatedElements = document.querySelectorAll('.scroll-animate');
  animatedElements.forEach(el => observer.observe(el));

  // Add scroll-animate class to specific sections
  const sectionsToAnimate = [
    '.feature-card',
    '.use-case-card',
    '.step',
    '.template-card',
    '.community-card'
  ];

  sectionsToAnimate.forEach(selector => {
    const elements = document.querySelectorAll(selector);
    elements.forEach(el => {
      el.classList.add('scroll-animate');
      observer.observe(el);
    });
  });
}

// ==================== STICKY HEADER ====================
function initStickyHeader() {
  const header = document.getElementById('header');
  let lastScroll = 0;

  window.addEventListener('scroll', () => {
    const currentScroll = window.pageYOffset;

    if (currentScroll > 100) {
      header.classList.add('scrolled');
    } else {
      header.classList.remove('scrolled');
    }

    lastScroll = currentScroll;
  });
}

// ==================== PLATFORM TABS ====================
function initPlatformTabs() {
  const tabs = document.querySelectorAll('.tab');
  const platformCodes = document.querySelectorAll('.platform-code');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const platform = tab.getAttribute('data-platform');

      // Remove active class from all tabs and code blocks
      tabs.forEach(t => t.classList.remove('active'));
      platformCodes.forEach(code => code.classList.remove('active'));

      // Add active class to clicked tab and corresponding code block
      tab.classList.add('active');
      const activeCode = document.querySelector(`.platform-code[data-platform="${platform}"]`);
      if (activeCode) {
        activeCode.classList.add('active');
      }
    });
  });
}

// ==================== COPY CODE BUTTON ====================
function initCopyButtons() {
  const copyButton = document.getElementById('copy-code');

  if (copyButton) {
    copyButton.addEventListener('click', async () => {
      const editor = window.monacoEditor;
      if (editor) {
        const code = editor.getValue();
        try {
          await navigator.clipboard.writeText(code);

          // Show feedback
          const originalText = copyButton.textContent;
          copyButton.textContent = 'Copied!';
          copyButton.style.background = 'rgba(76, 175, 80, 0.2)';
          copyButton.style.borderColor = '#4CAF50';

          setTimeout(() => {
            copyButton.textContent = originalText;
            copyButton.style.background = '';
            copyButton.style.borderColor = '';
          }, 2000);
        } catch (err) {
          console.error('Failed to copy code:', err);
        }
      }
    });
  }
}

// ==================== UTILITY FUNCTIONS ====================

// Smooth scroll to anchor (fallback for older browsers)
function smoothScroll(target) {
  const element = document.querySelector(target);
  if (element) {
    const headerOffset = 70;
    const elementPosition = element.getBoundingClientRect().top;
    const offsetPosition = elementPosition + window.pageYOffset - headerOffset;

    window.scrollTo({
      top: offsetPosition,
      behavior: 'smooth'
    });
  }
}

// Add smooth scrolling to all anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const href = this.getAttribute('href');
    if (href && href !== '#') {
      e.preventDefault();
      smoothScroll(href);
    }
  });
});
