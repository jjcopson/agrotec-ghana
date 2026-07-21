-- ============================================================
-- AGROTECH GHANA
-- Migration 004: Knowledge Hub, Courses, Posts
-- ============================================================

CREATE TYPE content_status AS ENUM (
  'draft', 'published', 'archived', 'flagged'
);

CREATE TYPE content_type AS ENUM (
  'article', 'video', 'infographic', 'podcast'
);

-- ============================================================
-- KNOWLEDGE POSTS (articles, tips)
-- ============================================================

CREATE TABLE public.knowledge_posts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id       UUID NOT NULL REFERENCES public.users(id),
  title           TEXT NOT NULL,
  slug            TEXT UNIQUE NOT NULL,
  summary         TEXT,
  content         TEXT NOT NULL,
  content_type    content_type NOT NULL DEFAULT 'article',
  cover_image_url TEXT,
  media_url       TEXT,
  tags            TEXT[],
  category        TEXT,
  status          content_status NOT NULL DEFAULT 'draft',
  is_premium      BOOLEAN NOT NULL DEFAULT FALSE,
  views_count     INTEGER NOT NULL DEFAULT 0,
  likes_count     INTEGER NOT NULL DEFAULT 0,
  comments_count  INTEGER NOT NULL DEFAULT 0,
  published_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.knowledge_post_likes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id     UUID NOT NULL REFERENCES public.knowledge_posts(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE TABLE public.knowledge_post_comments (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id     UUID NOT NULL REFERENCES public.knowledge_posts(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.users(id),
  parent_id   UUID REFERENCES public.knowledge_post_comments(id),
  content     TEXT NOT NULL,
  likes_count INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- COURSES (structured learning)
-- ============================================================

CREATE TABLE public.courses (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  instructor_id   UUID NOT NULL REFERENCES public.users(id),
  title           TEXT NOT NULL,
  slug            TEXT UNIQUE NOT NULL,
  description     TEXT,
  cover_image_url TEXT,
  preview_video   TEXT,
  category        TEXT,
  tags            TEXT[],
  difficulty      TEXT NOT NULL DEFAULT 'beginner',  -- beginner, intermediate, advanced
  language        TEXT NOT NULL DEFAULT 'en',
  is_free         BOOLEAN NOT NULL DEFAULT FALSE,
  price_ghs       DECIMAL(10,2) NOT NULL DEFAULT 0,
  status          content_status NOT NULL DEFAULT 'draft',
  enrolled_count  INTEGER NOT NULL DEFAULT 0,
  rating          DECIMAL(3,2) DEFAULT 0,
  total_lessons   INTEGER NOT NULL DEFAULT 0,
  duration_hours  DECIMAL(5,2),
  published_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.course_sections (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id   UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.course_lessons (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id       UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  section_id      UUID REFERENCES public.course_sections(id),
  title           TEXT NOT NULL,
  content         TEXT,
  video_url       TEXT,
  duration_mins   INTEGER,
  order_index     INTEGER NOT NULL DEFAULT 0,
  is_preview      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.course_enrollments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id       UUID NOT NULL REFERENCES public.courses(id),
  user_id         UUID NOT NULL REFERENCES public.users(id),
  payment_status  TEXT NOT NULL DEFAULT 'unpaid',
  amount_paid_ghs DECIMAL(10,2) NOT NULL DEFAULT 0,
  paystack_ref    TEXT,
  progress_pct    INTEGER NOT NULL DEFAULT 0,
  completed_at    TIMESTAMPTZ,
  enrolled_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(course_id, user_id)
);

CREATE TABLE public.lesson_progress (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  enrollment_id   UUID NOT NULL REFERENCES public.course_enrollments(id) ON DELETE CASCADE,
  lesson_id       UUID NOT NULL REFERENCES public.course_lessons(id),
  is_completed    BOOLEAN NOT NULL DEFAULT FALSE,
  watch_seconds   INTEGER NOT NULL DEFAULT 0,
  completed_at    TIMESTAMPTZ,
  UNIQUE(enrollment_id, lesson_id)
);

-- ============================================================
-- COMMUNITY FORUM (Q&A)
-- ============================================================

CREATE TABLE public.forum_posts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id       UUID NOT NULL REFERENCES public.users(id),
  title           TEXT NOT NULL,
  content         TEXT NOT NULL,
  tags            TEXT[],
  category        TEXT,
  is_expert_only  BOOLEAN NOT NULL DEFAULT FALSE,
  views_count     INTEGER NOT NULL DEFAULT 0,
  answers_count   INTEGER NOT NULL DEFAULT 0,
  is_solved       BOOLEAN NOT NULL DEFAULT FALSE,
  accepted_answer_id UUID,
  status          content_status NOT NULL DEFAULT 'published',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.forum_answers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id         UUID NOT NULL REFERENCES public.forum_posts(id) ON DELETE CASCADE,
  author_id       UUID NOT NULL REFERENCES public.users(id),
  content         TEXT NOT NULL,
  is_expert       BOOLEAN NOT NULL DEFAULT FALSE,
  upvotes         INTEGER NOT NULL DEFAULT 0,
  is_accepted     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE TRIGGER knowledge_posts_updated_at BEFORE UPDATE ON public.knowledge_posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER courses_updated_at BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER course_lessons_updated_at BEFORE UPDATE ON public.course_lessons FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER forum_posts_updated_at BEFORE UPDATE ON public.forum_posts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER forum_answers_updated_at BEFORE UPDATE ON public.forum_answers FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-increment post counts
CREATE OR REPLACE FUNCTION increment_post_like()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.knowledge_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_post_like AFTER INSERT ON public.knowledge_post_likes FOR EACH ROW EXECUTE FUNCTION increment_post_like();

CREATE OR REPLACE FUNCTION decrement_post_like()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.knowledge_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_post_unlike AFTER DELETE ON public.knowledge_post_likes FOR EACH ROW EXECUTE FUNCTION decrement_post_like();

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.knowledge_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.knowledge_post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forum_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Published posts visible to all" ON public.knowledge_posts FOR SELECT USING (status = 'published');
CREATE POLICY "Authors manage own posts" ON public.knowledge_posts FOR ALL USING (auth.uid() = author_id);
CREATE POLICY "Authenticated users like posts" ON public.knowledge_post_likes FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Authenticated users comment" ON public.knowledge_post_comments FOR SELECT USING (TRUE);
CREATE POLICY "Authenticated users add comments" ON public.knowledge_post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Published courses visible to all" ON public.courses FOR SELECT USING (status = 'published');
CREATE POLICY "Instructors manage own courses" ON public.courses FOR ALL USING (auth.uid() = instructor_id);
CREATE POLICY "Course sections visible to enrolled" ON public.course_sections FOR SELECT USING (TRUE);
CREATE POLICY "Lessons visible to enrolled" ON public.course_lessons FOR SELECT USING (
  is_preview = TRUE OR
  EXISTS (SELECT 1 FROM public.course_enrollments e WHERE e.course_id = course_id AND e.user_id = auth.uid() AND e.payment_status = 'paid')
  OR EXISTS (SELECT 1 FROM public.courses c WHERE c.id = course_id AND c.instructor_id = auth.uid())
);
CREATE POLICY "Enrollments visible to user" ON public.course_enrollments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users enroll" ON public.course_enrollments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Progress visible to user" ON public.lesson_progress FOR ALL USING (
  EXISTS (SELECT 1 FROM public.course_enrollments e WHERE e.id = enrollment_id AND e.user_id = auth.uid())
);
CREATE POLICY "Forum posts visible to all" ON public.forum_posts FOR SELECT USING (status = 'published');
CREATE POLICY "Authenticated users post forum" ON public.forum_posts FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Forum answers visible to all" ON public.forum_answers FOR SELECT USING (TRUE);
CREATE POLICY "Authenticated users answer" ON public.forum_answers FOR INSERT WITH CHECK (auth.uid() = author_id);

-- Indexes
CREATE INDEX idx_knowledge_posts_author ON public.knowledge_posts (author_id);
CREATE INDEX idx_knowledge_posts_status ON public.knowledge_posts (status, published_at DESC);
CREATE INDEX idx_knowledge_posts_tags ON public.knowledge_posts USING GIN (tags);
CREATE INDEX idx_courses_instructor ON public.courses (instructor_id);
CREATE INDEX idx_courses_status ON public.courses (status, published_at DESC);
CREATE INDEX idx_enrollments_user ON public.course_enrollments (user_id);
CREATE INDEX idx_enrollments_course ON public.course_enrollments (course_id);
CREATE INDEX idx_forum_posts_author ON public.forum_posts (author_id);
CREATE INDEX idx_forum_posts_status ON public.forum_posts (status, created_at DESC);
