import re

# Read SVG
with open('wl4-dual-deployment-annotated.svg', 'r') as f:
    svg = f.read()

# Find WL4 - Test text element and extract coordinates
# Looking for pattern like: <text ... x="XXXX" y="YYYY" ...>WL4 - Test
pattern = r'<text[^>]*x="([^"]+)"[^>]*y="([^"]+)"[^>]*>[^<]*WL4 - Test'
match = re.search(pattern, svg)

if match:
    text_x = float(match.group(1))
    text_y = float(match.group(2))
    print(f"Found WL4 - Test at x={text_x}, y={text_y}")
    
    # Find the rectangle that contains this text (WL4 Test box)
    # Search backwards from the text position for rectangles
    # This is approximate - look for rectangles near these coordinates
    
    # Based on the Excalidraw coordinates, WL4 Test box is approximately:
    # Center around the text, with the box being roughly 500 wide x 400 tall
    box_x = text_x - 50
    box_y = text_y + 50  # Below the text
    box_width = 500
    box_height = 400
    
    # Position for missing DEV (above Test)
    dev_x = box_x + 100
    dev_y = box_y - 500
    
    # Position for dual deployment annotation (inside Test box)
    dual_x = box_x + 50
    dual_y = box_y + box_height - 180  # Near bottom of Test box
    
    annotations = f'''
  <!-- ADR-005 Annotations: Missing DEV and Dual Deployment -->
  <g id="adr-005-annotations">
    <!-- Red X for Missing DEV (above Test box) -->
    <line x1="{dev_x}" y1="{dev_y}" x2="{dev_x + 120}" y2="{dev_y + 100}" 
          stroke="#e03131" stroke-width="10" opacity="0.9"/>
    <line x1="{dev_x + 120}" y1="{dev_y}" x2="{dev_x}" y2="{dev_y + 100}" 
          stroke="#e03131" stroke-width="10" opacity="0.9"/>
    <text x="{dev_x + 60}" y="{dev_y + 130}" 
          font-family="Arial, sans-serif" font-size="28" font-weight="bold" 
          fill="#e03131" text-anchor="middle">❌ MISSING DEV</text>
    
    <!-- Dual Deployment Annotation INSIDE TEST box -->
    <rect x="{dual_x}" y="{dual_y}" width="380" height="75" 
          fill="#ffc9c9" stroke="#e03131" stroke-width="4" rx="8" opacity="0.9"/>
    <text x="{dual_x + 190}" y="{dual_y + 32}" 
          font-family="Arial, sans-serif" font-size="26" font-weight="bold" 
          fill="#e03131" text-anchor="middle">⚠️ DUAL DEPLOYMENT</text>
    <text x="{dual_x + 190}" y="{dual_y + 58}" 
          font-family="Arial, sans-serif" font-size="22" font-weight="bold" 
          fill="#e03131" text-anchor="middle">(2x instances)</text>
  </g>
'''
    
    # Insert before closing svg tag
    svg = svg.replace('</svg>', annotations + '\n</svg>')
    
    with open('wl4-dual-deployment-annotated.svg', 'w') as f:
        f.write(svg)
    
    print(f"✓ Annotations added!")
    print(f"  - Missing DEV X at: ({dev_x:.0f}, {dev_y:.0f})")
    print(f"  - Dual deployment box at: ({dual_x:.0f}, {dual_y:.0f}) - INSIDE Test box")
else:
    print("❌ Could not find WL4 - Test in SVG")

