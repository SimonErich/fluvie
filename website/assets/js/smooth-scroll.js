// ==================== SMOOTH SCROLL POLYFILL ====================

// Enhanced smooth scrolling with easing for better UX
(function() {
  'use strict';

  // Check if smooth scroll is already supported
  if ('scrollBehavior' in document.documentElement.style) {
    return; // Native smooth scroll is available
  }

  // Polyfill for smooth scroll
  const easeInOutCubic = (t) => {
    return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1;
  };

  const smoothScrollTo = (targetPosition, duration = 800) => {
    const startPosition = window.pageYOffset;
    const distance = targetPosition - startPosition;
    let startTime = null;

    const animation = (currentTime) => {
      if (startTime === null) startTime = currentTime;
      const timeElapsed = currentTime - startTime;
      const progress = Math.min(timeElapsed / duration, 1);
      const ease = easeInOutCubic(progress);

      window.scrollTo(0, startPosition + distance * ease);

      if (timeElapsed < duration) {
        requestAnimationFrame(animation);
      }
    };

    requestAnimationFrame(animation);
  };

  // Override window.scrollTo for smooth behavior
  const originalScrollTo = window.scrollTo;
  window.scrollTo = function(x, y) {
    if (typeof x === 'object' && x.behavior === 'smooth') {
      smoothScrollTo(x.top || y);
    } else {
      originalScrollTo.call(window, x, y);
    }
  };

  // Handle anchor links
  document.addEventListener('click', (e) => {
    const anchor = e.target.closest('a[href^="#"]');
    if (!anchor) return;

    const href = anchor.getAttribute('href');
    if (!href || href === '#') return;

    const target = document.querySelector(href);
    if (!target) return;

    e.preventDefault();

    const headerOffset = 70;
    const elementPosition = target.getBoundingClientRect().top;
    const offsetPosition = elementPosition + window.pageYOffset - headerOffset;

    smoothScrollTo(offsetPosition);

    // Update URL without jumping
    if (history.pushState) {
      history.pushState(null, null, href);
    }
  });
})();

// ==================== SCROLL REVEAL UTILITY ====================

// Progressive reveal of sections as user scrolls
class ScrollReveal {
  constructor(options = {}) {
    this.options = {
      threshold: options.threshold || 0.1,
      rootMargin: options.rootMargin || '0px 0px -100px 0px',
      reset: options.reset || false,
      ...options
    };

    this.observer = null;
    this.elements = new Set();
  }

  init() {
    if (!('IntersectionObserver' in window)) {
      // Fallback: show all elements immediately
      this.elements.forEach(el => el.classList.add('active'));
      return;
    }

    this.observer = new IntersectionObserver(
      this.handleIntersection.bind(this),
      this.options
    );

    this.elements.forEach(el => this.observer.observe(el));
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('active');

        // Stop observing if reset is not enabled
        if (!this.options.reset) {
          this.observer.unobserve(entry.target);
        }
      } else if (this.options.reset) {
        entry.target.classList.remove('active');
      }
    });
  }

  observe(selector) {
    const elements = document.querySelectorAll(selector);
    elements.forEach(el => {
      this.elements.add(el);
    });
  }

  destroy() {
    if (this.observer) {
      this.observer.disconnect();
    }
    this.elements.clear();
  }
}

// Initialize scroll reveal on DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initScrollReveal);
} else {
  initScrollReveal();
}

function initScrollReveal() {
  const scrollReveal = new ScrollReveal({
    threshold: 0.15,
    rootMargin: '0px 0px -50px 0px'
  });

  // Elements to reveal on scroll
  const revealSelectors = [
    '.section__title',
    '.section__subtitle',
    '.feature-card',
    '.use-case-card',
    '.step',
    '.template-card',
    '.docs-category',
    '.community-card'
  ];

  revealSelectors.forEach(selector => {
    scrollReveal.observe(selector);
  });

  scrollReveal.init();
}

// ==================== PARALLAX SCROLL EFFECT ====================

// Subtle parallax effect for hero section (optional)
function initParallax() {
  const hero = document.querySelector('.hero');
  if (!hero) return;

  let ticking = false;

  window.addEventListener('scroll', () => {
    if (!ticking) {
      window.requestAnimationFrame(() => {
        const scrolled = window.pageYOffset;
        const parallaxSpeed = 0.5;

        if (scrolled < window.innerHeight) {
          hero.style.transform = `translateY(${scrolled * parallaxSpeed}px)`;
        }

        ticking = false;
      });

      ticking = true;
    }
  });
}

// Only enable parallax on devices that can handle it
if (window.matchMedia('(prefers-reduced-motion: no-preference)').matches) {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initParallax);
  } else {
    initParallax();
  }
}

// ==================== SCROLL PROGRESS INDICATOR ====================

// Optional: Add a scroll progress bar at the top of the page
function initScrollProgress() {
  const progressBar = document.createElement('div');
  progressBar.className = 'scroll-progress';
  progressBar.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    height: 3px;
    background: linear-gradient(90deg, #0175C2, #7C4DFF);
    z-index: 9999;
    transition: width 0.2s ease;
    width: 0;
  `;
  document.body.appendChild(progressBar);

  window.addEventListener('scroll', () => {
    const windowHeight = document.documentElement.scrollHeight - window.innerHeight;
    const scrolled = (window.pageYOffset / windowHeight) * 100;
    progressBar.style.width = `${scrolled}%`;
  });
}

// Uncomment to enable scroll progress bar
// if (document.readyState === 'loading') {
//   document.addEventListener('DOMContentLoaded', initScrollProgress);
// } else {
//   initScrollProgress();
// }
