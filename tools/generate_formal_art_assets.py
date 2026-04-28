#!/usr/bin/env python3
"""Generate route-specific formal runtime SVG assets.

The art pipeline keeps source/reference images out of runtime. This tool writes
pure SVG exports that Godot can load directly and that remain small enough for
the Web demo.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _write(path: str, svg: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(svg.strip() + "\n", encoding="utf-8")
    print(path)


def _defs(route: str) -> str:
    accent = "#7b1e17" if route == "spear" else "#8a251b"
    metal = "#b8aa86" if route == "spear" else "#c2ae82"
    return f"""
  <defs>
    <linearGradient id="paper" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#211f1b"/>
      <stop offset="0.48" stop-color="#312b23"/>
      <stop offset="1" stop-color="#151513"/>
    </linearGradient>
    <radialGradient id="fire" cx="64%" cy="42%" r="58%">
      <stop offset="0" stop-color="#9c4424" stop-opacity="0.44"/>
      <stop offset="0.45" stop-color="#5a1d16" stop-opacity="0.18"/>
      <stop offset="1" stop-color="#0c0c0b" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="robe" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{accent}"/>
      <stop offset="0.58" stop-color="#411715"/>
      <stop offset="1" stop-color="#171311"/>
    </linearGradient>
    <linearGradient id="armor" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#44413a"/>
      <stop offset="0.48" stop-color="#22231f"/>
      <stop offset="1" stop-color="#0f1110"/>
    </linearGradient>
    <linearGradient id="metal" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#5c574a"/>
      <stop offset="0.48" stop-color="{metal}"/>
      <stop offset="1" stop-color="#302d28"/>
    </linearGradient>
    <filter id="softShadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="12" stdDeviation="12" flood-color="#000000" flood-opacity="0.55"/>
    </filter>
  </defs>
"""


def _shared_bust_body() -> str:
    return """
  <ellipse cx="320" cy="688" rx="245" ry="40" fill="#050505" opacity="0.46"/>
  <path d="M120 684 C136 570 176 494 238 456 C272 436 363 436 401 456 C468 493 507 572 522 684 Z" fill="url(#robe)" filter="url(#softShadow)"/>
  <path d="M178 682 C183 565 223 493 280 463 L320 496 L360 463 C421 494 458 570 464 682 Z" fill="url(#armor)" opacity="0.96"/>
  <path d="M228 478 C250 519 287 545 320 551 C354 545 389 518 412 478 C384 451 353 438 320 438 C287 438 256 451 228 478 Z" fill="#5d1b18" opacity="0.84"/>
  <path d="M229 512 L411 512 L433 681 L205 681 Z" fill="#191b18" opacity="0.62"/>
  <g stroke="#95845b" stroke-width="3" opacity="0.58">
    <path d="M236 528 H404"/>
    <path d="M226 566 H414"/>
    <path d="M218 604 H422"/>
    <path d="M211 642 H429"/>
  </g>
  <g fill="#0c0d0c" opacity="0.58">
    <rect x="251" y="514" width="18" height="163"/>
    <rect x="302" y="514" width="18" height="164"/>
    <rect x="353" y="514" width="18" height="163"/>
  </g>
  <path d="M231 489 C177 532 154 601 152 686 L218 686 C216 598 236 540 278 503 Z" fill="#211a17" opacity="0.94"/>
  <path d="M409 489 C464 532 487 601 489 686 L422 686 C424 598 404 540 362 503 Z" fill="#211a17" opacity="0.94"/>
  <path d="M246 380 C245 429 276 463 320 463 C365 463 396 429 394 380 C384 343 356 322 320 322 C284 322 257 343 246 380 Z" fill="#b9966d"/>
  <path d="M249 386 C267 348 299 335 329 336 C365 337 388 358 395 388 C396 349 381 316 352 303 C330 291 294 295 275 310 C250 330 239 356 249 386 Z" fill="#10100f"/>
  <path d="M258 349 C286 330 344 327 386 353" fill="none" stroke="#6f1b17" stroke-width="15" stroke-linecap="round"/>
  <path d="M276 386 C292 377 307 377 320 386 C335 377 350 377 365 386" fill="none" stroke="#2a2622" stroke-width="5" stroke-linecap="round"/>
  <path d="M294 411 C311 421 329 421 347 411" fill="none" stroke="#6e4633" stroke-width="4" stroke-linecap="round"/>
  <path d="M306 440 C315 445 326 445 335 440" fill="none" stroke="#5b3428" stroke-width="3" stroke-linecap="round"/>
  <path d="M283 305 C265 331 257 360 254 397" fill="none" stroke="#0a0a09" stroke-width="18" stroke-linecap="round"/>
  <path d="M356 303 C381 326 394 357 395 398" fill="none" stroke="#0a0a09" stroke-width="17" stroke-linecap="round"/>
  <path d="M287 459 L320 500 L353 459" fill="none" stroke="#8d7852" stroke-width="6" stroke-linejoin="round" opacity="0.74"/>
  <circle cx="320" cy="502" r="7" fill="#a98545" opacity="0.86"/>
"""


def hero_bust(route: str) -> str:
    assert route in {"spear", "saber"}
    bg = """
  <rect width="640" height="720" fill="url(#paper)"/>
  <rect width="640" height="720" fill="url(#fire)"/>
  <path d="M50 130 C160 82 220 106 320 84 C430 60 522 90 594 40" fill="none" stroke="#a98c55" stroke-width="3" opacity="0.13"/>
  <path d="M0 618 C122 592 206 604 326 581 C456 556 552 578 640 544 L640 720 L0 720 Z" fill="#111411" opacity="0.70"/>
"""
    if route == "spear":
        weapon = """
  <g filter="url(#softShadow)">
    <path d="M64 638 L536 132" stroke="#6b4b2d" stroke-width="15" stroke-linecap="round"/>
    <path d="M88 662 L558 156" stroke="#17110d" stroke-width="4" stroke-linecap="round" opacity="0.55"/>
    <path d="M548 126 L596 64 L581 139 Z" fill="url(#metal)"/>
    <path d="M538 157 C570 162 579 183 600 206" fill="none" stroke="#6f1c16" stroke-width="7" stroke-linecap="round" opacity="0.82"/>
    <path d="M525 170 C554 185 561 204 579 235" fill="none" stroke="#8a3825" stroke-width="5" stroke-linecap="round" opacity="0.66"/>
    <path d="M162 547 C209 533 261 516 311 493" stroke="#bda46b" stroke-width="13" stroke-linecap="round"/>
    <path d="M155 548 C208 544 260 524 314 500" stroke="#4b251b" stroke-width="7" stroke-linecap="round"/>
  </g>
"""
        route_marks = """
  <path d="M150 248 C205 228 253 219 315 226" fill="none" stroke="#bda46b" stroke-width="3" opacity="0.33"/>
  <path d="M140 270 C196 250 257 245 333 255" fill="none" stroke="#4e5b55" stroke-width="4" opacity="0.24"/>
"""
    else:
        weapon = """
  <g filter="url(#softShadow)">
    <path d="M412 252 C500 323 518 436 462 562" fill="none" stroke="#271d18" stroke-width="26" stroke-linecap="round"/>
    <path d="M417 242 C500 322 513 427 457 554" fill="none" stroke="url(#metal)" stroke-width="11" stroke-linecap="round"/>
    <path d="M397 287 L432 249 L451 270 L414 307 Z" fill="#a98545"/>
    <path d="M204 646 C289 620 362 588 446 534" fill="none" stroke="#211914" stroke-width="18" stroke-linecap="round"/>
    <path d="M209 643 C292 617 366 586 441 536" fill="none" stroke="#725238" stroke-width="10" stroke-linecap="round"/>
    <path d="M376 525 C414 507 448 501 484 506" fill="none" stroke="#bda46b" stroke-width="13" stroke-linecap="round"/>
    <path d="M375 528 C413 517 449 512 484 516" fill="none" stroke="#4b251b" stroke-width="7" stroke-linecap="round"/>
  </g>
"""
        route_marks = """
  <path d="M150 244 C201 239 245 252 296 285" fill="none" stroke="#bda46b" stroke-width="3" opacity="0.32"/>
  <path d="M134 268 C197 269 250 285 318 327" fill="none" stroke="#4e5b55" stroke-width="4" opacity="0.22"/>
"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 720">
{_defs(route)}
{bg}
{route_marks}
{weapon}
{_shared_bust_body()}
  <path d="M178 681 C242 658 399 658 462 681" fill="none" stroke="#d1b070" stroke-width="3" opacity="0.32"/>
</svg>"""


def hero_performance(route: str) -> str:
    assert route in {"spear", "saber"}
    bg = """
  <rect width="360" height="520" fill="none"/>
  <ellipse cx="180" cy="494" rx="122" ry="20" fill="#050505" opacity="0.46"/>
"""
    body = """
  <path d="M103 490 C110 400 125 322 153 258 L206 258 C235 319 251 400 257 490 Z" fill="url(#robe)" opacity="0.96"/>
  <path d="M126 486 C132 394 146 322 168 268 L193 268 C217 323 231 395 236 486 Z" fill="url(#armor)" opacity="0.96"/>
  <path d="M141 270 C133 240 139 207 156 188 C171 171 195 171 210 189 C229 212 228 246 218 273 C201 287 163 287 141 270 Z" fill="#ae8b64"/>
  <path d="M142 218 C154 184 184 170 212 190 C221 198 225 211 226 231 C207 215 173 210 142 218 Z" fill="#0c0c0b"/>
  <path d="M143 206 C165 190 202 190 226 209" fill="none" stroke="#6d1b16" stroke-width="8" stroke-linecap="round"/>
  <path d="M154 235 C166 228 181 228 192 236 C204 229 215 230 225 239" fill="none" stroke="#211d19" stroke-width="3" stroke-linecap="round"/>
  <path d="M164 256 C176 263 191 263 204 256" fill="none" stroke="#5e382d" stroke-width="3" stroke-linecap="round"/>
  <g stroke="#947f55" stroke-width="2.5" opacity="0.62">
    <path d="M134 310 H226"/>
    <path d="M130 348 H230"/>
    <path d="M127 386 H233"/>
    <path d="M124 424 H236"/>
  </g>
  <path d="M103 490 L71 506 L110 340 Z" fill="#171513" opacity="0.88"/>
  <path d="M257 490 L291 506 L250 340 Z" fill="#171513" opacity="0.88"/>
"""
    if route == "spear":
        weapon = """
  <path d="M40 470 L305 88" stroke="#684727" stroke-width="9" stroke-linecap="round"/>
  <path d="M51 483 L316 100" stroke="#19120d" stroke-width="2.8" stroke-linecap="round" opacity="0.55"/>
  <path d="M310 83 L338 38 L333 91 Z" fill="url(#metal)"/>
  <path d="M297 111 C322 121 327 141 342 162" fill="none" stroke="#7d2018" stroke-width="5" stroke-linecap="round" opacity="0.80"/>
  <path d="M86 403 C122 389 151 374 184 353" stroke="#a98d5a" stroke-width="9" stroke-linecap="round"/>
  <path d="M88 407 C125 398 153 383 186 362" stroke="#3b1c16" stroke-width="5" stroke-linecap="round"/>
"""
        push = "-15"
    else:
        weapon = """
  <path d="M229 188 C296 245 308 337 263 448" fill="none" stroke="#241b16" stroke-width="18" stroke-linecap="round"/>
  <path d="M231 181 C292 243 301 334 259 438" fill="none" stroke="url(#metal)" stroke-width="7" stroke-linecap="round"/>
  <path d="M213 218 L235 190 L250 206 L226 233 Z" fill="#a98545"/>
  <path d="M76 470 C139 455 202 425 263 384" fill="none" stroke="#211914" stroke-width="13" stroke-linecap="round"/>
  <path d="M80 467 C142 450 202 421 260 386" fill="none" stroke="#725238" stroke-width="7" stroke-linecap="round"/>
  <path d="M201 384 C226 370 252 367 279 371" fill="none" stroke="#a98d5a" stroke-width="9" stroke-linecap="round"/>
  <path d="M201 389 C226 381 253 378 279 382" fill="none" stroke="#3b1c16" stroke-width="5" stroke-linecap="round"/>
"""
        push = "10"
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 520">
{_defs(route)}
{bg}
  <g transform="translate({push} 0)" filter="url(#softShadow)">
{weapon}
{body}
  </g>
</svg>"""


def main() -> None:
    _write("assets/pixel_battle/portraits/hero_officer_spear_bust.svg", hero_bust("spear"))
    _write("assets/pixel_battle/portraits/hero_officer_saber_bust.svg", hero_bust("saber"))
    _write("assets/pixel_battle/portraits/performance_hero_spear.svg", hero_performance("spear"))
    _write("assets/pixel_battle/portraits/performance_hero_saber.svg", hero_performance("saber"))


if __name__ == "__main__":
    main()
