-- 025_storage.sql — buckets + storage.objects policies
-- Apply in the live project AFTER confirming bucket names are free.
-- Do not treat this as already deployed; Dashboard Storage may already
-- use different ids. If so, rename the bucket_id predicates, not the columns.

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('product-images', 'product-images', true),
  ('cms', 'cms', true),
  ('pod', 'pod', false)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public;

-- storage.objects already has RLS enabled in hosted Supabase.

DROP POLICY IF EXISTS product_images_public_read ON storage.objects;
DROP POLICY IF EXISTS product_images_staff_insert ON storage.objects;
DROP POLICY IF EXISTS product_images_staff_update ON storage.objects;
DROP POLICY IF EXISTS product_images_staff_delete ON storage.objects;

DROP POLICY IF EXISTS cms_public_read ON storage.objects;
DROP POLICY IF EXISTS cms_staff_insert ON storage.objects;
DROP POLICY IF EXISTS cms_staff_update ON storage.objects;
DROP POLICY IF EXISTS cms_staff_delete ON storage.objects;

DROP POLICY IF EXISTS pod_staff_or_courier_read ON storage.objects;
DROP POLICY IF EXISTS pod_staff_or_courier_insert ON storage.objects;
DROP POLICY IF EXISTS pod_staff_or_courier_update ON storage.objects;
DROP POLICY IF EXISTS pod_staff_delete ON storage.objects;

-- Catalogue images: anyone may read; only staff may write.
CREATE POLICY product_images_public_read
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

CREATE POLICY product_images_staff_insert
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images' AND public.is_staff());

CREATE POLICY product_images_staff_update
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product-images' AND public.is_staff())
WITH CHECK (bucket_id = 'product-images' AND public.is_staff());

CREATE POLICY product_images_staff_delete
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images' AND public.is_staff());

-- CMS media (banners, videos, testimonial photos)
CREATE POLICY cms_public_read
ON storage.objects FOR SELECT
USING (bucket_id = 'cms');

CREATE POLICY cms_staff_insert
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'cms' AND public.is_staff());

CREATE POLICY cms_staff_update
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'cms' AND public.is_staff())
WITH CHECK (bucket_id = 'cms' AND public.is_staff());

CREATE POLICY cms_staff_delete
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'cms' AND public.is_staff());

-- POD evidence: never public. Staff or the assigned courier.
CREATE POLICY pod_staff_or_courier_read
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'pod'
  AND (
    public.is_staff()
    OR EXISTS (
      SELECT 1 FROM public.couriers c
      WHERE c.auth_user_id = auth.uid()
        AND c.is_active
    )
  )
);

CREATE POLICY pod_staff_or_courier_insert
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pod'
  AND (
    public.is_staff()
    OR EXISTS (
      SELECT 1 FROM public.couriers c
      WHERE c.auth_user_id = auth.uid()
        AND c.is_active
    )
  )
);

CREATE POLICY pod_staff_or_courier_update
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'pod'
  AND (
    public.is_staff()
    OR EXISTS (
      SELECT 1 FROM public.couriers c
      WHERE c.auth_user_id = auth.uid()
        AND c.is_active
    )
  )
)
WITH CHECK (
  bucket_id = 'pod'
  AND (
    public.is_staff()
    OR EXISTS (
      SELECT 1 FROM public.couriers c
      WHERE c.auth_user_id = auth.uid()
        AND c.is_active
    )
  )
);

CREATE POLICY pod_staff_delete
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'pod' AND public.is_staff());
