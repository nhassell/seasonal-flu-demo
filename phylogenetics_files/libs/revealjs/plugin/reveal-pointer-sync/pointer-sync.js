/**
 * Reveal.js RevealPointerSync Plugin
 */
window.RevealPointerSync = (function() {
  
  let windowType = window.location.search.includes('receiver') ? 'NOTES' : 'MAIN';
  let speakerWindow = null;
  let currentSlideWindow = null;
  let pointer = null;
  let isPointerActive = false;
  let isPointerDisabled = false;
  
  // Base pointer size (ratio of the slide width)
  const POINTER_SIZE_RATIO = 2 / 100;  // 2% of the slide width

  const isMac = navigator.userAgent.toUpperCase().includes('MAC');
  
  // Create the laser pointer shape with an initial size
  function createPointer() {
    const p = document.createElement('div');
    p.id = 'reveal-pointer-sync';
    
    p.style.cssText = `
      position: fixed;
      border-radius: 50%;
      background: rgba(255, 0, 0, 0.7);
      border: 2px solid rgba(255, 255, 255, 0.9);
      pointer-events: none;
      z-index: 9999;
      display: none;
      transform: translate(-50%, -50%);
      transition: width 0.05s, height 0.05s, border-width 0.05s;
    `;
    document.body.appendChild(p);
    
    return p;
  }
  
  // Transform slide coordinates into relative coordinates
  function getSlideCoordinates(clientX, clientY) {
    const slides = document.querySelector('.reveal .slides');
    if (!slides) return null;
    
    const rect = slides.getBoundingClientRect();
    const relX = (clientX - rect.left) / rect.width;
    const relY = (clientY - rect.top) / rect.height;
    
    return { relX, relY };
  }
  
  // Convert relative coordinates to actual coordinates and size
  function getActualCoordinates(relX, relY) {
    const slides = document.querySelector('.reveal .slides');
    if (!slides) return null;
    
    const rect = slides.getBoundingClientRect();
    
    // Calculate the pointer size from the slide width
    const pointerSize = rect.width * POINTER_SIZE_RATIO;
    
    return {
      x: rect.left + rect.width * relX,
      y: rect.top + rect.height * relY,
      size: pointerSize
    };
  }
  
  // Show the pointer (dynamically adjust the size)
  function showPointer(x, y, size) {
    if (pointer) {
      const borderWidth = Math.max(size * 0.1, 1);  // 10% of the size (minimum: 1 px)
      
      pointer.style.left = x + 'px';
      pointer.style.top = y + 'px';
      pointer.style.width = size + 'px';
      pointer.style.height = size + 'px';
      pointer.style.borderWidth = borderWidth + 'px';
      pointer.style.display = 'block';
    }
  }
  
  // Hide the pointer
  function hidePointer() {
    if (pointer) {
      pointer.style.display = 'none';
    }
  }
  
  // Send the pointer state
  function broadcastPointer(coords, type) {
    const message = {
      namespace: 'reveal-pointer-sync',
      type: type,
      from: windowType,
      relX: coords ? coords.relX : 0,
      relY: coords ? coords.relY : 0,
    };
    
    // Send a message to the NOTES view (from MAIN)
    if (windowType === 'MAIN' && speakerWindow && !speakerWindow.closed) {
      if (currentSlideWindow) {
        currentSlideWindow.postMessage(JSON.stringify(message), '*');
      }
    }
    
    // Send a message to the MAIN window (from NOTES)
    if (windowType === 'NOTES' && window.parent.opener) {
      window.parent.opener.postMessage(JSON.stringify(message), '*');
    }
  }

  // update the current-slide window in NOTES
  function updateNotesIframeWindow(event) {
    if (currentSlideWindow !== event.source) {
      currentSlideWindow = event.source;
    }
  }
  
  function setKeepAlive(windowType) {
    // Notify the iframe window of current
    //
    // Quick hack: The speaker view contains two iframes: one for the current slide
    // and one for the upcoming slide. They have the same contents, but display
    // different slides.
    // I couldn't find a reliable way to distinguish them from inside the iframe,
    // so as a workaround, I use `postMessageEvents=true` to detect the current slide,
    // since the upcoming one doesn't have this parameter.
    if (windowType === 'NOTES' && window.location.search.includes('postMessageEvents=true')) {
      const message = {
        namespace: 'reveal-pointer-sync',
        type: 'keepalive',
        from: windowType
      }
      const intervalId = setInterval(() => {
        window.parent.opener.postMessage(JSON.stringify(message), '*');
      }, 1000);
    }
  }

  return {
    id: 'RevealPointerSync',
    init: (deck) => {
      pointer = createPointer();
      
      console.log('========================================');
      console.log(`[${windowType}] RevealPointerSync Plugin initialized`);
      console.log('========================================');
      
      // Message listener
      window.addEventListener('message', (event) => {
        let data = event.data;
        
        if (typeof data === 'string') {
          try {
            data = JSON.parse(data);
          } catch (e) {
            return;
          }
        }
        
        // Obtain the window reference from reveal-notes
        if (data && data.namespace === 'reveal-notes') {
          if (event.source && event.source !== window) {
            speakerWindow = event.source;
            // console.log(`[${windowType}] ✅ Speaker view captured`);
          }
        }
        
        // Processing the reveal-pointer-sync messages
        if (data && data.namespace === 'reveal-pointer-sync') {
          if (data.type === 'move') {
            const actual = getActualCoordinates(data.relX, data.relY);
            if (actual) {
              // Render the pointer based on its coordinates and size
              showPointer(actual.x, actual.y, actual.size);
            }
          } else if (data.type === 'hide') {
            hidePointer();
          } else if (data.type === 'flag') {
            flagstr = isPointerDisabled ? "en" : "dis";
            console.log(`[${windowType}] Pointer is ${flagstr}abled.`)
            isPointerDisabled = !isPointerDisabled;
          } else if (data.type === 'keepalive') {
            updateNotesIframeWindow(event);
          }
        }
      });
      
      // Mouse movement event
      document.addEventListener('pointermove', (event) => {
        if (isPointerDisabled) return;

        const ctrlKey = isMac ? event.metaKey : event.ctrlKey;
        if (ctrlKey) {
          if (!isPointerActive) {
            isPointerActive = true;
            console.log(`[${windowType}] Pointer ON`);
          }
          
          const coords = getSlideCoordinates(event.clientX, event.clientY);
          if (coords) {
            // Render in the current window by calculating the current window size
            const actual = getActualCoordinates(coords.relX, coords.relY);
            if (actual) {
              showPointer(event.clientX, event.clientY, actual.size);
            }
            
            broadcastPointer(coords, 'move');
          }
        } else if (isPointerActive) {
          isPointerActive = false;
          hidePointer();
          broadcastPointer(null, 'hide');
          console.log(`[${windowType}] Pointer OFF`);
        }
      });
      
      document.addEventListener('keydown', (event) => {
        const ctrlKey = isMac ? event.metaKey : event.ctrlKey;
        if (event.key === 'p' && event.altKey) {
          event.preventDefault();
          event.stopPropagation();
          flagstr = isPointerDisabled ? "en" : "dis";
          console.log(`[${windowType}] Pointer is ${flagstr}abled.`)
          isPointerDisabled = !isPointerDisabled;
          broadcastPointer(null, 'flag');
        }
      }, true);
      
      // Hide the laser pointer if the Ctrl key is up
      document.addEventListener('keyup', (event) => {
        if (isPointerDisabled) return;

        const ctrlKey = isMac ? 'Meta' : 'Control';
        if (event.key === ctrlKey) {
          isPointerActive = false;
          hidePointer();
          broadcastPointer(null, 'hide');
          console.log(`[${windowType}] Pointer OFF (key up)`);
        }
      });

      setKeepAlive(windowType);
      
      console.log(`[${windowType}] 💡 Press 'S' to open speaker view`);
      console.log(`[${windowType}] 💡 Press 'Ctrl' and move mouse to show the laser pointer`);
      console.log(`[${windowType}] 💡 Press 'Alt' + 'P' to enable/disable the laser pointer`);
    }
  };

})();
