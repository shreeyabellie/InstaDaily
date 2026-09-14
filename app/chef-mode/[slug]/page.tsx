import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createClient } from '../../../apps/web/lib/supabase/server';

export default async function RecipePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const supabase = await createClient();
  const { data: recipe, error } = await supabase
    .from('recipes')
    .select('title, description, prep_time_minutes, cook_time_minutes, servings, recipe_ingredients(quantity, unit, optional, notes, ingredients(name))')
    .eq('slug', slug)
    .single();

  if (error || !recipe) notFound();
  return <main><Link href="/">← Back to shop</Link><h1>{recipe.title}</h1><p>{recipe.description}</p><p>Prep {recipe.prep_time_minutes} min · Cook {recipe.cook_time_minutes} min · Serves {recipe.servings}</p><h2>Ingredients</h2><ul>{recipe.recipe_ingredients.map((item: any) => <li key={`${item.ingredients?.name}-${item.quantity}`}>{item.quantity} {item.unit} {item.ingredients?.name}{item.optional ? ' (optional)' : ''}</li>)}</ul></main>;
}
