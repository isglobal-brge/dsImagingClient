test_that("imaging radiomics profiles and segmenters are built", {
  profile <- ds.imaging.radiomics.profile.demo_ct_firstorder()
  expect_equal(profile$name, "demo_ct_firstorder_v1")
  expect_false(profile$force2D)
  expect_equal(profile$feature_classes, "firstorder")

  segmenter <- ds.imaging.segmenter.ct_lung_threshold(
    threshold = -400,
    max_components = 3,
    min_voxels = 200)
  expect_equal(segmenter$provider, "ct_lung_threshold")
  expect_equal(segmenter$threshold, -400)
  expect_equal(segmenter$max_components, 3L)
})

test_that("legacy radiomics aliases map to imaging constructors", {
  expect_equal(
    ds.radiomics.profile.aerts_signature(),
    ds.imaging.radiomics.profile.aerts_signature())

  expect_equal(
    ds.segmenter.lungmask("R231"),
    ds.imaging.segmenter.lungmask("R231"))
})
