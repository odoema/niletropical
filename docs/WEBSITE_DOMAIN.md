# Nile Tropical website and app URLs

The published Pages artifact contains:
- Public website at the site root.
- Flutter commerce app at `/app/` for the custom domain.
- Flutter commerce app at `/niletropical/app/` for the GitHub project URL.

GitHub project URL: https://odoema.github.io/niletropical/
Custom domain: https://niletropicaluganda.com/

The website uses relative `./app/` links so the same website works from either hosting location. The Flutter build receives an explicit base href for each location.
