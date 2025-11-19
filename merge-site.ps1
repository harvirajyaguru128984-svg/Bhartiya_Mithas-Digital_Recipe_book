# Merge Bharatiya Mithas site into a single-page app (single.html)
# Usage: pwsh -File .\merge-site.ps1

$ErrorActionPreference = 'Stop'

# 1) Read CSS
$cssPath = Join-Path $PSScriptRoot 'style.css'
if (-not (Test-Path $cssPath)) { throw "style.css not found at $cssPath" }
$css = Get-Content $cssPath -Raw

# 2) Define source pages and their SPA routes
$pages = @(
  @{ route = 'home';              path = 'index.html';                          ctx = 'client' }
  @{ route = 'recipes';           path = 'recipes.html';                        ctx = 'client' }
  @{ route = 'recipe';            path = 'recipe.html';                         ctx = 'client' }
  @{ route = 'about';             path = 'about.html';                          ctx = 'client' }
  @{ route = 'contact';           path = 'contact.html';                        ctx = 'client' }
  @{ route = 'admin';             path = 'admin/index.html';                    ctx = 'admin'  }
  @{ route = 'admin-recipes';     path = 'admin/recipes.html';                  ctx = 'admin'  }
  @{ route = 'admin-add';         path = 'admin/add-recipe.html';               ctx = 'admin'  }
  @{ route = 'admin-edit';        path = 'admin/edit-recipe.html';              ctx = 'admin'  }
  @{ route = 'admin-categories';  path = 'admin/categories.html';               ctx = 'admin'  }
)

function Get-MainHtml([string]$html){
  # Extract the first <main ...>...</main>; fallback to <body>...
  $mainRegex = [regex]::new('<main[^>]*>([\s\S]*?)</main>', 'IgnoreCase')
  $m = $mainRegex.Match($html)
  if ($m.Success) { return $m.Groups[1].Value }
  $bodyRegex = [regex]::new('<body[^>]*>([\s\S]*?)</body>', 'IgnoreCase')
  $b = $bodyRegex.Match($html)
  if ($b.Success) { return $b.Groups[1].Value }
  return $html
}

function Rewrite-Links([string]$html, [string]$ctx){
  # Normalize hrefs that point to individual files into hash routes
  # Common client links
  $mapCommon = @{
    'href="index.html"'            = 'href="#home"'
    'href="/index.html"'           = 'href="#home"'
    'href="../index.html"'         = 'href="#home"'
    'href="recipes.html"'          = 'href="#recipes"'
    'href="/recipes.html"'         = 'href="#recipes"'
    'href="../recipes.html"'       = 'href="#recipes"'
    'href="recipe.html"'           = 'href="#recipe"'
    'href="/recipe.html"'          = 'href="#recipe"'
    'href="../recipe.html"'        = 'href="#recipe"'
    'href="about.html"'            = 'href="#about"'
    'href="/about.html"'           = 'href="#about"'
    'href="../about.html"'         = 'href="#about"'
    'href="contact.html"'          = 'href="#contact"'
    'href="/contact.html"'         = 'href="#contact"'
    'href="../contact.html"'       = 'href="#contact"'
    'href="admin/index.html"'      = 'href="#admin"'
    'href="/admin/index.html"'     = 'href="#admin"'
    'href="../admin/index.html"'   = 'href="#admin"'
  }

  # Admin-only intra-admin links
  $mapAdmin = @{
    'href="recipes.html"'          = 'href="#admin-recipes"'
    'href="add-recipe.html"'       = 'href="#admin-add"'
    'href="edit-recipe.html"'      = 'href="#admin-edit"'
    'href="categories.html"'       = 'href="#admin-categories"'
    'href="../recipes.html"'       = 'href="#admin-recipes"'
    'href="../add-recipe.html"'    = 'href="#admin-add"'
    'href="../edit-recipe.html"'   = 'href="#admin-edit"'
    'href="../categories.html"'    = 'href="#admin-categories"'
  }

  foreach($k in $mapCommon.Keys){ $html = $html -replace [regex]::Escape($k), $mapCommon[$k] }
  if ($ctx -eq 'admin'){
    foreach($k in $mapAdmin.Keys){ $html = $html -replace [regex]::Escape($k), $mapAdmin[$k] }
  }
  return $html
}

# 3) Build sections by reading pages
$sections = @()
foreach($p in $pages){
  $fullPath = Join-Path $PSScriptRoot $p.path
  if (-not (Test-Path $fullPath)) { throw "Missing page: $($p.path)" }
  $raw = Get-Content $fullPath -Raw
  $main = Get-MainHtml $raw
  $rewritten = Rewrite-Links $main $p.ctx
  $hiddenAttr = if ($p.route -eq 'home') { '' } else { ' hidden' }
  $sections += "<section data-route=\"$($p.route)\"$hiddenAttr>$rewritten</section>"
}

# 4) Compose final single.html
$head = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bharatiya Mithas • Single Page</title>
  <style>
$css
  /* Minor single-page additions */
  .admin-subnav{display:flex;gap:10px;margin:8px 0 16px}
  .admin-subnav a{padding:6px 10px;border:1px solid var(--border);border-radius:8px;color:#333}
  .admin-subnav a.active{background:rgba(139,30,63,.08)}
  </style>
</head>
<body>
  <header class="header">
    <nav class="nav">
      <a class="brand" href="#home"><span class="logo"></span> Bharatiya Mithas</a>
      <div class="menu" id="top-menu">
        <a data-nav="home" href="#home">Home</a>
        <a data-nav="recipes" href="#recipes">Recipes</a>
        <a data-nav="about" href="#about">About</a>
        <a data-nav="contact" href="#contact">Contact</a>
        <a data-nav="admin" href="#admin">Admin</a>
      </div>
    </nav>
  </header>
  <main class="container">
"@

$foot = @"
  </main>
  <footer class="footer"><div class="container">© <span id="year"></span> Bharatiya Mithas</div></footer>
  <script>
    // Basic SPA router
    const sections = Array.from(document.querySelectorAll('[data-route]'));
    const validRoutes = new Set(sections.map(s => s.dataset.route));
    function setActiveTopNav(route){
      document.querySelectorAll('#top-menu a').forEach(a=>{
        a.classList.remove('active');
        const key = a.getAttribute('data-nav');
        if(route.startsWith('admin') ? key==='admin' : key===route) a.classList.add('active');
      });
    }
    function showRoute(route){
      if(!validRoutes.has(route)) route = 'home';
      sections.forEach(s=>{ s.hidden = s.dataset.route !== route; });
      setActiveTopNav(route);
      // sync admin subnav highlight if present
      document.querySelectorAll('.admin-subnav a').forEach(a=>{
        a.classList.toggle('active', a.getAttribute('href') === '#'+route);
      });
      window.scrollTo({top:0,behavior:'instant'});
    }
    window.addEventListener('hashchange',()=>showRoute(location.hash.replace('#','')||'home'));

    // Demo recipes data + rendering for Recipes page
    const recipesData = [
      {id:1,title:'Gulab Jamun',cat:'Khoya',img:'https://via.placeholder.com/640x400?text=Gulab+Jamun'},
      {id:2,title:'Rasgulla',cat:'Chhena',img:'https://via.placeholder.com/640x400?text=Rasgulla'},
      {id:3,title:'Mysore Pak',cat:'Flour-based',img:'https://via.placeholder.com/640x400?text=Mysore+Pak'},
      {id:4,title:'Kaju Katli',cat:'Dry sweets',img:'https://via.placeholder.com/640x400?text=Kaju+Katli'},
      {id:5,title:'Besan Laddu',cat:'Flour-based',img:'https://via.placeholder.com/640x400?text=Besan+Laddu'},
      {id:6,title:'Sandesh',cat:'Chhena',img:'https://via.placeholder.com/640x400?text=Sandesh'}
    ];
    function renderRecipes(){
      const grid = document.getElementById('recipes-grid');
      const search = document.getElementById('recipes-search');
      const filter = document.getElementById('recipes-filter');
      if(!grid) return;
      grid.innerHTML = '';
      const q = (search?.value||'').toLowerCase();
      const f = filter?.value||'';
      recipesData.filter(r=>(!q||r.title.toLowerCase().includes(q)) && (!f||r.cat===f))
        .forEach(r=>{
          const a = document.createElement('a');
          a.href = '#recipe';
          a.className='card';
          a.innerHTML = `<img src="${r.img}" alt="${r.title}"><div class="body"><h3>${r.title}</h3><div class="meta">Category: ${r.cat}</div></div>`;
          grid.appendChild(a);
        });
    }
    document.getElementById('recipes-search')?.addEventListener('input',renderRecipes);
    document.getElementById('recipes-filter')?.addEventListener('change',renderRecipes);

    // Admin categories demo helpers
    function removeCat(e,name){ e?.preventDefault?.(); alert('Demo: removed '+name); e?.target?.parentElement?.remove(); }
    function addCat(){ const i=document.getElementById('newcat'); if(!i||!i.value.trim()) return; const li=document.createElement('li'); li.innerHTML=i.value+" <a href='#' onclick=\"removeCat(event,'"+i.value+"')\">Remove</a>"; document.getElementById('cat-list').appendChild(li); i.value=''; }
    window.removeCat = removeCat; window.addCat = addCat;

    // Initialize
    document.getElementById('year').textContent = new Date().getFullYear();
    renderRecipes();
    showRoute(location.hash.replace('#','')||'home');
  </script>
</body>
</html>
"@

$outPath = Join-Path $PSScriptRoot 'single.html'

# Write output
$head | Out-File -FilePath $outPath -Encoding UTF8
$sections -join "`n`n" | Out-File -FilePath $outPath -Append -Encoding UTF8
$foot | Out-File -FilePath $outPath -Append -Encoding UTF8

Write-Host "Created: $outPath"