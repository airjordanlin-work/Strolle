-- Seeds the skills table from content/question_bank/skills.json.
-- skill_ability.skill is a foreign key to skills(slug), so grade-attempt
-- cannot write a rating until these rows exist. sat_weight is the domain
-- weight split evenly across the domain's skills, the same split
-- weightsFromTaxonomy() does in functions/_shared/adaptive.ts.
--
-- Taxonomy only, no question content. Re-runnable: edits to the weights
-- in skills.json land by re-running this (or a later migration).

insert into skills (slug, section, domain, sat_weight) values
  ('linear-equations', 'math', 'algebra', 0.07000),
  ('linear-functions', 'math', 'algebra', 0.07000),
  ('linear-equations-two-variables', 'math', 'algebra', 0.07000),
  ('systems-of-linear-equations', 'math', 'algebra', 0.07000),
  ('linear-inequalities', 'math', 'algebra', 0.07000),
  ('equivalent-expressions', 'math', 'advanced-math', 0.11667),
  ('nonlinear-equations', 'math', 'advanced-math', 0.11667),
  ('nonlinear-functions', 'math', 'advanced-math', 0.11667),
  ('ratios-rates-proportions', 'math', 'problem-solving-data-analysis', 0.02143),
  ('percentages', 'math', 'problem-solving-data-analysis', 0.02143),
  ('units', 'math', 'problem-solving-data-analysis', 0.02143),
  ('one-variable-data', 'math', 'problem-solving-data-analysis', 0.02143),
  ('two-variable-data', 'math', 'problem-solving-data-analysis', 0.02143),
  ('probability', 'math', 'problem-solving-data-analysis', 0.02143),
  ('sample-inference', 'math', 'problem-solving-data-analysis', 0.02143),
  ('area-volume', 'math', 'geometry-trigonometry', 0.03750),
  ('lines-angles-triangles', 'math', 'geometry-trigonometry', 0.03750),
  ('right-triangles-trig', 'math', 'geometry-trigonometry', 0.03750),
  ('circles', 'math', 'geometry-trigonometry', 0.03750),
  ('vocabulary-in-context', 'reading', 'craft-structure', 0.09333),
  ('text-structure-purpose', 'reading', 'craft-structure', 0.09333),
  ('cross-text-connections', 'reading', 'craft-structure', 0.09333),
  ('central-ideas', 'reading', 'information-ideas', 0.06500),
  ('command-of-evidence-textual', 'reading', 'information-ideas', 0.06500),
  ('command-of-evidence-quantitative', 'reading', 'information-ideas', 0.06500),
  ('inferences', 'reading', 'information-ideas', 0.06500),
  ('boundaries', 'writing', 'standard-english-conventions', 0.13000),
  ('form-structure-sense', 'writing', 'standard-english-conventions', 0.13000),
  ('transitions', 'writing', 'expression-of-ideas', 0.10000),
  ('rhetorical-synthesis', 'writing', 'expression-of-ideas', 0.10000)
on conflict (slug) do update
  set section = excluded.section,
      domain = excluded.domain,
      sat_weight = excluded.sat_weight;
